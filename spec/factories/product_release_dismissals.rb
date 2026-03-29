FactoryBot.define do
  factory :product_release_dismissal do
    association :product_release
    association :user
    dismissed_at { Time.current }
  end
end
