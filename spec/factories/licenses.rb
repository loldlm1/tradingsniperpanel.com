FactoryBot.define do
  factory :license do
    association :user
    association :expert_advisor
    status { "trial" }
    plan_interval { nil }
    trial_ends_at { 3.days.from_now }
    source { "spec" }
    encrypted_key do
      Licenses::LicenseKeyEncoder.new(
        primary_key: ENV.fetch("EA_LICENSE_PRIMARY_KEY", "PRIMARY_KEY"),
        secondary_key: ENV.fetch("EA_LICENSE_SECRET_KEY", "SECONDARY_KEY")
      ).generate(email: user.email, ea_id: expert_advisor.ea_id)
    end
  end
end
