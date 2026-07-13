require "rails_helper"

RSpec.describe ExpertAdvisors::ShowPresenter, type: :service do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Atlas Core EA") }
  let(:license) { create(:license, user: user, expert_advisor: expert_advisor, status: "active", last_synced_at: Time.utc(2025, 1, 20)) }
  let(:entry) do
    Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: license,
      status: :active,
      accessible: true,
      expires_at: license.expires_at,
      license_key: license.encrypted_key,
      allowed_tiers: ["starter"]
    )
  end

  it "orders owned addons first and includes all add-ons" do
    product_a = create(:marketplace_product, title_en: "Addon A", sort_order: 1)
    product_b = create(:marketplace_product, title_en: "Addon B", sort_order: 2)
    product_c = create(:marketplace_product, title_en: "Addon C", sort_order: 3)
    product_d = create(:marketplace_product, title_en: "Addon D", sort_order: 4)

    addon_a = create(:addon, addonable: expert_advisor, billing_plan: product_a.billing_plan)
    addon_b = create(:addon, addonable: expert_advisor, billing_plan: product_b.billing_plan)
    addon_c = create(:addon, addonable: expert_advisor, billing_plan: product_c.billing_plan)
    addon_d = create(:addon, addonable: expert_advisor, billing_plan: product_d.billing_plan)

    create(:marketplace_purchase, user: user, billing_plan: product_b.billing_plan)

    presenter = described_class.new(
      user: user,
      expert_advisor: expert_advisor,
      entry: entry,
      locale: :en,
      marketplace_available: true
    )
    items = presenter.addons_summary[:items]

    expect(items.size).to eq(4)
    expect(items.first.owned).to eq(true)
    expect(items.first.guide_url).to eq(
      Rails.application.routes.url_helpers.dashboard_expert_advisor_addon_guide_path(
        expert_advisor,
        addon_key: addon_b.key,
        locale: :en
      )
    )
    expect(items.map(&:title)).to eq([addon_b, addon_a, addon_c, addon_d].map { |addon| addon.marketplace_product.title_en })
  end

  it "builds pnl and balance charts for the last 30 days" do
    account = create(:broker_account, license: license, company: "BrokerX", account_number: 123456)
    create(:broker_account_daily_result, broker_account: account, result_timestamp: Time.utc(2025, 1, 15, 12).to_i, result_value: 25.0)
    create(:broker_account_daily_result, broker_account: account, result_timestamp: Time.utc(2025, 1, 16, 12).to_i, result_value: -5.0)

    presenter = described_class.new(
      user: user,
      expert_advisor: expert_advisor,
      entry: entry,
      locale: :en,
      now: Time.utc(2025, 1, 30)
    )
    pnl_chart = presenter.pnl_summary[:chart]
    balance_chart = presenter.balance_summary[:chart]

    expect(pnl_chart).to be_present
    expect(pnl_chart[:datasets].first[:data].size).to eq(30)
    expect(balance_chart[:labels]).to include("BrokerX")
  end

  it "reports broker account counts and last sync" do
    create(:broker_account, license: license, company: "BrokerY", account_number: 654321)

    presenter = described_class.new(
      user: user,
      expert_advisor: expert_advisor,
      entry: entry,
      locale: :en
    )
    details = presenter.system_details
    labels = details.map { |row| row[:label] }
    values = details.map { |row| row[:value] }

    expect(labels).to include(I18n.t("dashboard.expert_advisors.show.details.broker_accounts", locale: :en))
    expect(values).to include(I18n.t("dashboard.expert_advisors.show.values.broker_accounts_count", count: 1, locale: :en))
  end

  it "does not mark add-ons as owned from a product role" do
    role_user = create(:user, :full_trader)
    role_license = create(:license, user: role_user, expert_advisor: expert_advisor, status: "active")
    role_entry = Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: role_license,
      status: :active,
      accessible: true,
      expires_at: role_license.expires_at,
      license_key: role_license.encrypted_key,
      allowed_tiers: ["starter"]
    )

    addon_product_one = create(:marketplace_product, title_en: "Role Addon A")
    addon_product_two = create(:marketplace_product, title_en: "Role Addon B")
    create(:addon, addonable: expert_advisor, billing_plan: addon_product_one.billing_plan)
    create(:addon, addonable: expert_advisor, billing_plan: addon_product_two.billing_plan)

    presenter = described_class.new(
      user: role_user,
      expert_advisor: expert_advisor,
      entry: role_entry,
      locale: :en,
      marketplace_available: true
    )
    summary = presenter.addons_summary

    expect(summary[:total_count]).to eq(2)
    expect(summary[:owned_count]).to eq(0)
    expect(summary[:progress_percent]).to eq(0)
    expect(summary[:items].map(&:owned)).to all(be(false))
  end

  it "selects the latest broker account by sync activity" do
    account_a = create(:broker_account, license: license, company: "BrokerA", account_number: 111111)
    account_b = create(:broker_account, license: license, company: "BrokerB", account_number: 222222)

    create(:broker_account_daily_result, broker_account: account_a, result_timestamp: Time.utc(2025, 1, 10, 12).to_i, result_value: 10.0)
    create(:broker_account_daily_result, broker_account: account_b, result_timestamp: Time.utc(2025, 1, 20, 12).to_i, result_value: 15.0)

    presenter = described_class.new(
      user: user,
      expert_advisor: expert_advisor,
      entry: entry,
      locale: :en
    )

    expect(presenter.latest_broker_account).to eq(account_b)
  end

  it "renders a lifetime expiration label for one-time licenses" do
    lifetime_license = create(:license, :one_time, user: user, expert_advisor: expert_advisor, status: "active")
    lifetime_entry = Licenses::AccessibleExpertAdvisors::Entry.new(
      expert_advisor: expert_advisor,
      license: lifetime_license,
      status: :active,
      accessible: true,
      expires_at: nil,
      license_key: lifetime_license.encrypted_key,
      allowed_tiers: ["starter"]
    )
    presenter = described_class.new(
      user: user,
      expert_advisor: expert_advisor,
      entry: lifetime_entry,
      locale: :en
    )
    expected_label = I18n.t(
      "dashboard.expert_advisors.show.expires_on",
      date: I18n.l(License::LIFETIME_EXPIRES_AT, format: :short_with_year, locale: :en),
      locale: :en
    )

    expect(presenter.license_expires_label).to eq(expected_label)
  end
end
