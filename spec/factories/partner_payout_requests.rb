FactoryBot.define do
  factory :partner_payout_request do
    association :partner_profile
    status { :pending }
    notification_status { :queued }
    total_cents { 25_000 }
    requested_at { Time.current }
  end
end
