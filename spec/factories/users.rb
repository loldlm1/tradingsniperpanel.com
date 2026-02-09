FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    name { "Test User" }
    preferred_locale { "en" }
    terms_accepted_at { Time.current }

    trait :spanish do
      preferred_locale { "es" }
    end

    trait :admin do
      role { :admin }
    end

    trait :partner do
      role { :partner }
    end

    trait :master_admin do
      role { :master_admin }
    end

    trait :full_trader do
      role { :full_trader }
    end
  end
end
