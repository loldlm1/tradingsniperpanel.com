FactoryBot.define do
  factory :license do
    association :user
    association :expert_advisor
    status { "trial" }
    plan_interval { nil }
    trial_ends_at { 3.days.from_now }
    expires_at { 14.days.from_now }
    source { "spec" }
    access_source { "subscription" }
    encrypted_key do
      key_expires_at =
        if status.to_s == "trial"
          trial_ends_at
        elsif access_source.to_s == "one_time" && expires_at.blank?
          License::LIFETIME_EXPIRES_AT
        else
          expires_at
        end
      Licenses::LicenseKeyEncoder.new(
        primary_key: ENV.fetch("EA_LICENSE_PRIMARY_KEY", "PRIMARY_KEY"),
        secondary_key: ENV.fetch("EA_LICENSE_SECRET_KEY", "SECONDARY_KEY")
      ).generate(
        email: user.email,
        ea_id: expert_advisor.ea_id,
        expires_at: key_expires_at,
        token_version: token_version
      )
    end

    trait :one_time do
      access_source { "one_time" }
      status { "active" }
      trial_ends_at { nil }
      expires_at { nil }
    end
  end
end
