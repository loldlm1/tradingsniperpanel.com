FactoryBot.define do
  factory :support_request do
    association :user
    message { "I need help with my account." }
    locale { "en" }
  end
end
