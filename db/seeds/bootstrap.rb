module Seeds
  module AdminBootstrap
    module_function

    def seed!
      return unless defined?(User) && defined?(RevenueSplitRule)

      master_email = required_env("MASTER_ADMIN_EMAIL")
      master_password = required_env("MASTER_ADMIN_PASSWORD")
      us_percent = required_env_int("REVENUE_SPLIT_US_PERCENT")
      client_percent = required_env_int("REVENUE_SPLIT_CLIENT_PERCENT")
      validate_split!(us_percent, client_percent)

      create_master_admin(email: master_email, password: master_password)
      upsert_split_rule(
        us_percent: us_percent,
        client_percent: client_percent,
        effective_at: parse_effective_at
      )
    end

    def create_master_admin(email:, password:)
      user = User.find_or_initialize_by(email: email)
      user.role = :master_admin
      user.terms_accepted_at ||= Time.current
      if user.new_record?
        user.password = password
        user.password_confirmation = password
      end
      user.save!
    end

    def upsert_split_rule(us_percent:, client_percent:, effective_at:)
      rule = RevenueSplitRule.ordered.first || RevenueSplitRule.new
      rule.effective_at = effective_at
      rule.us_percent = us_percent
      rule.client_percent = client_percent
      rule.save!

      RevenueSplitRule.where.not(id: rule.id).delete_all
    end

    def parse_effective_at
      raw = ENV.fetch("REVENUE_SPLIT_EFFECTIVE_AT", "").to_s.strip
      return Time.current.utc.beginning_of_day if raw.empty?

      parsed = Time.zone&.parse(raw) || Time.parse(raw)
      parsed.utc
    rescue ArgumentError
      raise "Invalid REVENUE_SPLIT_EFFECTIVE_AT: #{raw.inspect}"
    end

    def required_env(key)
      value = ENV.fetch(key, "").to_s.strip
      return value if value.present?

      raise "Missing required env var: #{key}"
    end

    def required_env_int(key)
      value = required_env(key)
      Integer(value, 10)
    rescue ArgumentError
      raise "Invalid #{key}: #{value.inspect}"
    end

    def validate_split!(us_percent, client_percent)
      unless us_percent.between?(0, 100) && client_percent.between?(0, 100)
        raise "Revenue split percentages must be between 0 and 100."
      end
      return if us_percent + client_percent == 100

      raise "Revenue split percentages must sum to 100."
    end
  end
end
