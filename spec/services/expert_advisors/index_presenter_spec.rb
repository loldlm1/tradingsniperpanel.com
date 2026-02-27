require "rails_helper"

RSpec.describe ExpertAdvisors::IndexPresenter, type: :service do
  it "marks addons as owned for privileged users" do
    privileged_user = create(:user, :full_trader)
    expert_advisor = create(:expert_advisor, name: "Privileged EA")
    license = create(:license, user: privileged_user, expert_advisor: expert_advisor, status: "active")
    entry = Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: license,
      status: :active,
      accessible: true,
      expires_at: license.expires_at,
      license_key: license.encrypted_key,
      allowed_tiers: ["starter"]
    )

    addon_product_one = create(:marketplace_product, title_en: "Addon One")
    addon_product_two = create(:marketplace_product, title_en: "Addon Two")
    create(:addon, addonable: expert_advisor, billing_plan: addon_product_one.billing_plan)
    create(:addon, addonable: expert_advisor, billing_plan: addon_product_two.billing_plan)

    presenter = described_class.new(
      entries: [entry],
      user: privileged_user,
      locale: :en,
      marketplace_available: true
    )
    card = presenter.cards.first

    expect(card.addons_total_count).to eq(2)
    expect(card.addons_owned_count).to eq(2)
    expect(card.addon_items.map(&:owned)).to eq([true, true])
  end

  it "builds a lifetime expiration label for one-time licenses" do
    user = create(:user)
    expert_advisor = create(:expert_advisor, name: "Lifetime EA")
    license = create(:license, :one_time, user: user, expert_advisor: expert_advisor, status: "active")
    entry = Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: license,
      status: :active,
      accessible: true,
      expires_at: nil,
      license_key: license.encrypted_key,
      allowed_tiers: ["starter"]
    )

    presenter = described_class.new(
      entries: [entry],
      user: user,
      locale: :en,
      marketplace_available: true
    )
    card = presenter.cards.first
    expected_label = I18n.t(
      "dashboard.expert_advisors.show.expires_on",
      date: I18n.l(License::LIFETIME_EXPIRES_AT, format: :short_with_year, locale: :en),
      locale: :en
    )

    expect(card.license_expires_label).to eq(expected_label)
  end
end
