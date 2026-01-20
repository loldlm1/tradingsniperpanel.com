FactoryBot.define do
  factory :marketplace_asset do
    sequence(:slug) { |n| "marketplace_asset_#{n}" }
    status { "active" }
    sort_order { 1 }
    title_en { "Marketplace Asset #{slug}" }
    title_es { "Recurso Marketplace #{slug}" }
    summary_en { "Downloadable asset for traders." }
    summary_es { "Recurso descargable para traders." }
    description_markdown_en { "## Asset details" }
    description_markdown_es { "## Detalles del recurso" }
  end
end
