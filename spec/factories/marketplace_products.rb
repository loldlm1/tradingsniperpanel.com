FactoryBot.define do
  factory :marketplace_product do
    association :billing_plan, factory: [:billing_plan, :one_time]
    sequence(:slug) { |n| "marketplace_product_#{n}" }
    key { "marketplace_#{slug}" }
    status { "active" }
    sort_order { 1 }
    title_en { "Marketplace Product #{slug}" }
    title_es { "Producto Marketplace #{slug}" }
    summary_en { "One-time bundle for trading." }
    summary_es { "Bundle de compra unica para trading." }
    description_en { "Lifetime access to curated Expert Advisors and courses." }
    description_es { "Acceso de por vida a Expert Advisors y cursos." }

    after(:build) do |product|
      plan = product.billing_plan
      next unless plan

      plan.key = product.key
      plan.name = product.title_en
      plan.kind = "one_time"
      plan.tier = nil
      plan.interval = nil
      plan.interval_count = nil
    end
  end
end
