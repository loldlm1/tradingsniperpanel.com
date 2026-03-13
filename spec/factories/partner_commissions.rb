FactoryBot.define do
  factory :partner_commission do
    association :partner_profile
    association :partner_membership
    association :referred_user, factory: :user
    commission_kind { :initial }
    status { :pending }
    amount_cents { 15_000 }
    currency { "usd" }
    percent_applied { 20 }
    occurred_at { Time.current }
  end
end
