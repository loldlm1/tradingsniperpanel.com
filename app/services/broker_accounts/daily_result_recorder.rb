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

    def call(source:, email:, ea_id:, license_key:, broker_account:, magic_number:, result_timestamp:, result_value:)
      verification = verifier.call(source:, email:, ea_id:, license_key:)
      return failure(verification.error, verification.code) unless verification.ok?

      normalized_broker = normalize_broker_account(broker_account)
      return failure(:invalid_payload, :unprocessable_content) if normalized_broker.nil?

      account = find_broker_account(verification.license, normalized_broker)
      return failure(:broker_account_not_found, :not_found) unless account

      parsed_magic_number = parse_magic_number(magic_number)
      return failure(:missing_magic_number, :unprocessable_content) if parsed_magic_number == :missing
      return failure(:invalid_magic_number, :unprocessable_content) if parsed_magic_number.nil?

      unless valid_lane_magic_number?(
        license: verification.license,
        source: source,
        email: email,
        broker_account: normalized_broker,
        magic_number: parsed_magic_number
      )
        return failure(:invalid_magic_number, :unprocessable_content)
      end

      timestamp = parse_timestamp(result_timestamp)
      return failure(:invalid_payload, :unprocessable_content) unless timestamp

      value = parse_value(result_value)
      return failure(:invalid_payload, :unprocessable_content) unless value

      return failure(:already_recorded, :conflict) if already_recorded?(
        broker_account_id: account.id,
        expert_advisor_id: verification.license.expert_advisor_id,
        magic_number: parsed_magic_number,
        timestamp: timestamp
      )

      daily_result = BrokerAccountDailyResult.create!(
        broker_account: account,
        expert_advisor: verification.license.expert_advisor,
        magic_number: parsed_magic_number,
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

    def find_broker_account(license, attrs)
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

    def parse_magic_number(raw)
      return :missing if raw.blank?

      value = Integer(raw.to_s, 10)
      return nil unless Licenses::MagicNumberPolicy.supported?(value)

      value
    rescue ArgumentError, TypeError
      nil
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

    def already_recorded?(broker_account_id:, expert_advisor_id:, magic_number:, timestamp:)
      date = Time.at(timestamp).utc.to_date
      BrokerAccountDailyResult
        .where(
          broker_account_id: broker_account_id,
          expert_advisor_id: expert_advisor_id,
          magic_number: magic_number
        )
        .where("((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date) = ?", date)
        .exists?
    end

    def valid_lane_magic_number?(license:, source:, email:, broker_account:, magic_number:)
      LicenseLaneMagicNumber.exists?(
        license_id: license.id,
        source: source.to_s.strip.downcase,
        email: email.to_s.strip.downcase,
        company: broker_account[:company].to_s.strip.downcase,
        account_number: broker_account[:account_number],
        account_type: broker_account[:account_type],
        magic_number: magic_number
      )
    end

    def success(daily_result)
      Result.new(ok: true, code: :created, daily_result: daily_result)
    end

    def failure(error, code)
      Result.new(ok: false, error: error, code: code)
    end
  end
end
