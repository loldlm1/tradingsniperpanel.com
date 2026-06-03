require "digest"

module Licenses
  class InstanceMagicNumberAllocator
    Result = Struct.new(:ok, :code, :error, :magic_number, :record, keyword_init: true) do
      def ok?
        !!self[:ok]
      end
    end

    MAX_ASSIGN_ATTEMPTS = 20

    def initialize(license:, source:, email:, broker_account:, instance_id:, now: Time.current, logger: Rails.logger)
      @license = license
      @source = source
      @email = email
      @broker_account = broker_account
      @instance_id = instance_id
      @now = now
      @logger = logger
    end

    def call
      return failure(:invalid_payload, :unprocessable_content) unless valid_context?

      normalized_instance_id = normalize_instance_id(instance_id)
      return failure(:missing_instance_id, :unprocessable_content) if normalized_instance_id.blank?
      return failure(:invalid_instance_id, :unprocessable_content) unless valid_instance_id?(normalized_instance_id)

      attrs = assignment_attrs(normalized_instance_id)
      return failure(:invalid_payload, :unprocessable_content) if attrs[:source].blank? || attrs[:email].blank?

      existing = find_existing(normalized_instance_id)
      return success(refresh_existing!(existing, attrs)) if existing&.transport_safe_magic_number?
      return success(remap_existing_magic_number!(existing, attrs)) if existing.present?

      success(assign_new_magic_number!(attrs))
    rescue ActiveRecord::RecordInvalid => e
      logger.warn(
        "[Licenses::InstanceMagicNumberAllocator] invalid payload " \
        "license_id=#{license&.id} broker_account_id=#{broker_account&.id} " \
        "instance_id_fingerprint=#{instance_id_fingerprint}: #{e.record.errors.full_messages.join(', ')}"
      )
      failure(:invalid_payload, :unprocessable_content)
    rescue StandardError => e
      logger.error(
        "[Licenses::InstanceMagicNumberAllocator] failed " \
        "license_id=#{license&.id} broker_account_id=#{broker_account&.id} " \
        "instance_id_fingerprint=#{instance_id_fingerprint}: #{e.class} - #{e.message}"
      )
      failure(:internal_error, :internal_server_error)
    end

    private

    attr_reader :license, :source, :email, :broker_account, :instance_id, :now, :logger

    def valid_context?
      return false unless license.is_a?(License) && license.persisted?
      return false unless broker_account.is_a?(BrokerAccount) && broker_account.persisted?
      return false if license.expert_advisor_id.blank?

      broker_account.license_id == license.id
    end

    def assignment_attrs(normalized_instance_id)
      {
        license_id: license.id,
        broker_account_id: broker_account.id,
        expert_advisor_id: license.expert_advisor_id,
        source: normalize_source(source),
        email: normalize_email(email),
        instance_id: normalized_instance_id
      }
    end

    def find_existing(normalized_instance_id)
      LicenseInstanceMagicNumber.find_by(
        broker_account_id: broker_account.id,
        expert_advisor_id: license.expert_advisor_id,
        instance_id: normalized_instance_id
      )
    end

    def refresh_existing!(record, attrs)
      refreshed = record.with_lock do
        record.reload
        next unless record.transport_safe_magic_number?

        record.update!(
          license_id: attrs[:license_id],
          source: attrs[:source],
          email: attrs[:email],
          last_seen_at: now
        )
        record
      end
      return refreshed if refreshed

      remap_existing_magic_number!(record, attrs)
    end

    def assign_new_magic_number!(attrs)
      attempts = 0

      loop do
        attempts += 1
        magic_number = generate_magic_number

        if magic_number_reserved?(magic_number)
          raise "instance magic assignment attempts exhausted" if attempts >= MAX_ASSIGN_ATTEMPTS

          next
        end

        begin
          return LicenseInstanceMagicNumber.create!(
            attrs.merge(
              magic_number: magic_number,
              first_seen_at: now,
              last_seen_at: now
            )
          )
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          existing = find_existing(attrs[:instance_id])
          return refresh_existing!(existing, attrs) if existing&.transport_safe_magic_number?
          return remap_existing_magic_number!(existing, attrs) if existing.present?

          raise unless retryable_magic_number_collision?(e)
          raise if attempts >= MAX_ASSIGN_ATTEMPTS
        end
      end
    end

    def remap_existing_magic_number!(record, attrs)
      attempts = 0

      loop do
        attempts += 1
        magic_number = generate_magic_number

        if magic_number_reserved?(magic_number, except_id: record.id)
          raise "instance magic remap attempts exhausted" if attempts >= MAX_ASSIGN_ATTEMPTS

          next
        end

        begin
          record.with_lock do
            record.reload
            if record.transport_safe_magic_number?
              record.update!(
                license_id: attrs[:license_id],
                source: attrs[:source],
                email: attrs[:email],
                last_seen_at: now
              )
              return record
            end

            previous_magic_number = record.magic_number
            record.update!(
              license_id: attrs[:license_id],
              source: attrs[:source],
              email: attrs[:email],
              magic_number: magic_number,
              last_seen_at: now
            )

            logger.info(
              "[Licenses::InstanceMagicNumberAllocator] remapped oversized magic_number " \
              "license_id=#{license.id} broker_account_id=#{broker_account.id} " \
              "instance_id_fingerprint=#{instance_id_fingerprint(attrs[:instance_id])} " \
              "old_magic_number=#{previous_magic_number} new_magic_number=#{record.magic_number}"
            )

            return record
          end
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          raise unless retryable_magic_number_collision?(e)
          raise if attempts >= MAX_ASSIGN_ATTEMPTS
        end
      end
    end

    def magic_number_reserved?(magic_number, except_id: nil)
      instance_scope = LicenseInstanceMagicNumber.where(
        broker_account_id: broker_account.id,
        magic_number: magic_number
      )
      instance_scope = instance_scope.where.not(id: except_id) if except_id

      instance_scope.exists? || legacy_lane_magic_number?(magic_number)
    end

    def legacy_lane_magic_number?(magic_number)
      LicenseLaneMagicNumber.exists?(
        company: broker_account.company.to_s.strip.downcase,
        account_number: broker_account.account_number,
        account_type: broker_account.account_type,
        magic_number: magic_number
      )
    end

    def generate_magic_number
      Licenses::MagicNumberPolicy.generate
    end

    def valid_instance_id?(value)
      value.length <= LicenseInstanceMagicNumber::MAX_INSTANCE_ID_LENGTH &&
        value.match?(LicenseInstanceMagicNumber::INSTANCE_ID_FORMAT)
    end

    def normalize_source(value)
      value.to_s.strip.downcase
    end

    def normalize_email(value)
      value.to_s.strip.downcase
    end

    def normalize_instance_id(value)
      value.to_s.strip
    end

    def retryable_magic_number_collision?(error)
      return true if error.is_a?(ActiveRecord::RecordNotUnique)
      return false unless error.is_a?(ActiveRecord::RecordInvalid)

      error.record.errors.of_kind?(:magic_number, :taken)
    end

    def instance_id_fingerprint(value = instance_id)
      normalized = normalize_instance_id(value)
      return "blank" if normalized.blank?

      Digest::SHA256.hexdigest(normalized)[0, 12]
    end

    def success(record)
      Result.new(ok: true, code: :ok, magic_number: record.magic_number, record: record)
    end

    def failure(error, code)
      Result.new(ok: false, error: error, code: code)
    end
  end
end
