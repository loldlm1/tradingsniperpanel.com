require "rails_helper"

RSpec.describe Marketing::DiscountBanner do
  it "returns localized banner payload for the active promotion" do
    promotion = create(
      :promotion_code,
      :active,
      code: "MARCH25",
      percent_off: 25,
      title_en: "March special",
      title_es: "Especial de marzo",
      body_en: "Fresh offer for traders.",
      body_es: "Oferta nueva para traders.",
      cta_label_en: "See plans",
      cta_label_es: "Ver planes"
    )

    expect(described_class.new(locale: :es).call).to eq(
      id: promotion.id,
      code: "MARCH25",
      percent: 25,
      title: "Especial de marzo",
      body: "Oferta nueva para traders.",
      cta_label: "Ver planes",
      updated_at: promotion.updated_at
    )
  end

  it "returns nil when no active promotion exists" do
    create(:promotion_code)

    expect(described_class.new.call).to be_nil
  end
end
