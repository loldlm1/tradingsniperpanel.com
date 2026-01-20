require "rails_helper"

RSpec.describe MarketplaceAsset, type: :model do
  it "normalizes the slug on create" do
    asset = described_class.new(
      slug: "My Asset",
      status: "active",
      sort_order: 0,
      title_en: "Asset",
      title_es: "Recurso"
    )

    asset.valid?

    expect(asset.slug).to eq("my_asset")
  end

  it "falls back to English content" do
    asset = described_class.new(
      slug: "asset",
      status: "active",
      sort_order: 0,
      title_en: "Asset",
      title_es: "Recurso",
      description_markdown_en: "## Details"
    )

    expect(asset.description_markdown_for(:es)).to eq("## Details")
  end
end
