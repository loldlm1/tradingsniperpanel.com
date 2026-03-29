FactoryBot.define do
  factory :product_release do
    association :published_by, factory: [:user, :admin]
    published_at { Time.current }
  end
end
