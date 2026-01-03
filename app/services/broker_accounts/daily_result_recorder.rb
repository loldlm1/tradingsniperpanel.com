module BrokerAccounts
  class DailyResultRecorder
    Result = Struct.new(:ok, :code, :error, :daily_result, keyword_init: true) do
      def ok?
        !!self[:ok]
      end
    end

    def initialize(verifier: Licenses::LicenseVerifier.new, logger: Rails.logger)
      @verifier = verifier
      @logger = logger
    end

    def call(source:, email:, ea_id:, license_key:, broker_account:, result_timestamp:, result_value:)
      verification = verifier.call(source:, email:, ea_id:, license_key:)
      return failure(verification.error, verification.code) unless verification.ok?

      account = find_broker_account(verification.license, broker_account)
      return failure(:broker_account_not_found, :not_found) unless account

      timestamp = parse_timestamp(result_timestamp)
      return failure(:invalid_payload, :unprocessable_content) unless timestamp

      value = parse_value(result_value)
      return failure(:invalid_payload, :unprocessable_content) unless value

      return failure(:already_recorded, :conflict) if already_recorded?(account.id, timestamp)

      daily_result = BrokerAccountDailyResult.create!(
        broker_account: account,
        result_timestamp: timestamp,
        result_value: value
      )

      success(daily_result)
    rescue ActiveRecord::RecordNotUnique
      failure(:already_recorded, :conflict)
    rescue ActiveRecord::RecordInvalid => e
      logger.warn(
        "[BrokerAccounts::DailyResultRecorder] invalid record broker_account_id=#{account&.id} result_timestamp=#{result_timestamp}: #{e.record.errors.full_messages.join(', ')}"
      )
      failure(:invalid_payload, :unprocessable_content)
    rescue StandardError => e
      logger.error(
        "[BrokerAccounts::DailyResultRecorder] failed email=#{email} ea_id=#{ea_id} broker_account_id=#{account&.id}: #{e.class} - #{e.message}"
      )
      failure(:internal_error, :internal_server_error)
    end

    private

    attr_reader :verifier, :logger

    def find_broker_account(license, broker_account)
      attrs = normalize_broker_account(broker_account)
      return nil if attrs.nil?

      BrokerAccount.find_by(
        license_id: license.id,
        company: attrs[:company],
        account_number: attrs[:account_number],
        account_type: attrs[:account_type]
      )
    end

    def normalize_broker_account(raw)
      attrs = raw.to_h.symbolize_keys
      return nil if attrs.blank?

      company = attrs[:company].to_s.strip
      account_number = safe_account_number(attrs[:account_number])
      account_type = attrs[:account_type].to_s

      return nil if company.blank? || account_number.nil?
      return nil unless BrokerAccount.account_types.key?(account_type)

      { company: company, account_number: account_number, account_type: account_type }
    end

    def safe_account_number(raw)
      return nil if raw.blank?

      Integer(raw.to_s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_timestamp(raw)
      return nil if raw.blank?

      value = Integer(raw.to_s, 10)
      value.positive? ? value : nil
    rescue ArgumentError, TypeError
      nil
    end

    def parse_value(raw)
      return nil if raw.blank?

      value = BigDecimal(raw.to_s)
      return nil if value.nan? || value.infinite?
      return nil if value.scale > 2

      value
    rescue ArgumentError
      nil
    end

    def already_recorded?(broker_account_id, timestamp)
      date = Time.at(timestamp).utc.to_date
      BrokerAccountDailyResult
        .where(broker_account_id: broker_account_id)
        .where("((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date) = ?", date)
        .exists?
    end

    def success(daily_result)
      Result.new(ok: true, code: :created, daily_result: daily_result)
    end

    def failure(error, code)
      Result.new(ok: false, error: error, code: code)
    end
  end
end
