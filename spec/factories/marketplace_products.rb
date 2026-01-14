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

  end
end
