module Seeds
  module Profiles
    module_function

    FULL_QA = "full_qa".freeze
    PROD_MIRROR = "prod_mirror".freeze
    VALID = [FULL_QA, PROD_MIRROR].freeze

    def current(environment: Rails.env)
      requested = ENV.fetch("SEED_PROFILE", "").to_s.strip
      profile = requested.presence || default_for(environment: environment)
      validate!(profile)
      ENV["SEED_PROFILE"] = profile
      profile
    end

    def default_for(environment: Rails.env)
      environment.to_s == "production" ? PROD_MIRROR : FULL_QA
    end

    def prod_mirror?(environment: Rails.env)
      current(environment: environment) == PROD_MIRROR
    end

    def full_qa?(environment: Rails.env)
      current(environment: environment) == FULL_QA
    end

    def validate!(profile)
      return if VALID.include?(profile.to_s)

      raise "Invalid SEED_PROFILE=#{profile.inspect}. Valid values: #{VALID.join(', ')}"
    end
  end
end
