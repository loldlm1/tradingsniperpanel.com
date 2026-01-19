FactoryBot.define do
  factory :revenue_split_payout do
    period_key { "first_half" }
    starts_at { Time.current.beginning_of_month }
    ends_at { (Time.current.beginning_of_month + 14.days).end_of_day }
    net_cents { 10_000 }
    us_cents { 4_000 }
    client_cents { 6_000 }
    status { :paid }
    paid_at { Time.current }
    association :paid_by_admin, factory: [:user, :master_admin]
    notes { "Payout locked" }
  end
end
