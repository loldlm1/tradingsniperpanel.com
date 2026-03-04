require "securerandom"

module Licenses
  class LaneMagicNumberAllocator
    Result = Struct.new(:ok, :code, :error, :magic_number, :record, keyword_init: true) do
      def ok?
        !!self[:ok]
      end
    end

    MAX_ASSIGN_ATTEMPTS = 20
    MAX_MAGIC_NUMBER = (2**63) - 1

    def initialize(license:, source:, email:, broker_account:, logger: Rails.logger)
      @license = license
      @source = source
      @email = email
      @broker_account = broker_account
      @logger = logger
    end

    def call
      identity = normalize_identity(broker_account)
      return failure(:invalid_payload, :unprocessable_content) if identity.nil?

      lane_attrs = {
        license_id: license.id,
        source: normalize_source(source),
        email: normalize_email(email),
        company: identity[:company],
        account_number: identity[:account_number],
        account_type: identity[:account_type]
      }
      return failure(:invalid_payload, :unprocessable_content) if lane_attrs[:source].blank? || lane_attrs[:email].blank?

      existing = LicenseLaneMagicNumber.find_by(lane_attrs)
      return success(existing) if existing&.magic_number.to_i.positive?

      assigned = assign_new_magic_number!(lane_attrs)
      success(assigned)
    rescue ActiveRecord::RecordInvalid => e
      logger.warn(
        "[Licenses::LaneMagicNumberAllocator] invalid payload license_id=#{license.id}: #{e.record.errors.full_messages.join(', ')}"
      )
      failure(:invalid_payload, :unprocessable_content)
    rescue StandardError => e
      logger.error("[Licenses::LaneMagicNumberAllocator] failed license_id=#{license.id}: #{e.class} - #{e.message}")
      failure(:internal_error, :internal_server_error)
    end

    private

    attr_reader :license, :source, :email, :broker_account, :logger

    def normalize_identity(raw)
      attrs = raw.to_h.symbolize_keys
      return nil if attrs.blank?

      company = attrs[:company].to_s.strip.downcase
      account_number = safe_account_number(attrs[:account_number])
      account_type = attrs[:account_type].to_s

      return nil if company.blank? || account_number.nil?
      return nil unless LicenseLaneMagicNumber.account_types.key?(account_type)

      { company: company, account_number: account_number, account_type: account_type }
    end

    def assign_new_magic_number!(lane_attrs)
      attempts = 0

      loop do
        attempts += 1
        begin
          return LicenseLaneMagicNumber.create!(lane_attrs.merge(magic_number: generate_magic_number))
        rescue ActiveRecord::RecordNotUnique
          existing = LicenseLaneMagicNumber.find_by(lane_attrs)
          return existing if existing&.magic_number.to_i.positive?

          raise if attempts >= MAX_ASSIGN_ATTEMPTS
        end
      end
    end

    def generate_magic_number
      SecureRandom.random_number(MAX_MAGIC_NUMBER) + 1
    end

    def safe_account_number(raw)
      return nil if raw.blank?

      Integer(raw.to_s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def normalize_source(value)
      value.to_s.strip.downcase
    end

    def normalize_email(value)
      value.to_s.strip.downcase
    end

    def success(record)
      Result.new(ok: true, code: :ok, magic_number: record.magic_number, record: record)
    end

    def failure(error, code)
      Result.new(ok: false, error: error, code: code)
    end
  end
end
