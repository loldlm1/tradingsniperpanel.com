FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    preferred_locale { "en" }

    trait :spanish do
      preferred_locale { "es" }
    end
  end
end
