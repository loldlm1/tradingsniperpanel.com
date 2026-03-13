FactoryBot.define do
  factory :partner_profile do
    association :user
    active { true }
    referral_code { "PART#{SecureRandom.alphanumeric(8).upcase}" }
    discount_percent { 10 }
    commission_percent { 20 }
    payout_mode { :once_paid }
    started_at { Time.current }
  end
end
