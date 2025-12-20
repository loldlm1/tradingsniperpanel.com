FactoryBot.define do
  factory :broker_account do
    association :license
    name { "Main Account" }
    company { "BrokerX" }
    account_number { 123456 }
    account_type { :real }
  end
end
