FactoryBot.define do
  factory :revenue_split_rule do
    effective_at { 1.day.ago }
    us_percent { 40 }
    client_percent { 60 }
    note { "Default split" }
  end
end
