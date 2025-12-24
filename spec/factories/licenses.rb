FactoryBot.define do
  factory :license do
    association :user
    association :expert_advisor
    status { "trial" }
    plan_interval { nil }
    trial_ends_at { 3.days.from_now }
    expires_at { 14.days.from_now }
    source { "spec" }
    encrypted_key do
      key_expires_at = status.to_s == "trial" ? trial_ends_at : expires_at
      Licenses::LicenseKeyEncoder.new(
        primary_key: ENV.fetch("EA_LICENSE_PRIMARY_KEY", "PRIMARY_KEY"),
        secondary_key: ENV.fetch("EA_LICENSE_SECRET_KEY", "SECONDARY_KEY")
      ).generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: key_expires_at)
    end
  end
end
