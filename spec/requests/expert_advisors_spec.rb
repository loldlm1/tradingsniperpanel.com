require "rails_helper"

RSpec.describe "Expert advisor guides", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) do
    create(:expert_advisor, doc_guide_en: "# Sniper Advanced Panel\n\nFirst paragraph.")
  end
  let(:bundle_path) { Rails.root.join("spec/fixtures/files/ea_bundle.rar") }

  before do
    sign_in user, scope: :user
  end

  def attach_bundle(record)
    File.open(bundle_path) do |file|
      record.ea_files.attach(
        io: file,
        filename: "ea_bundle.rar",
        content_type: "application/x-rar-compressed"
      )
    end
  end

  def attach_ea_bundle(bundle, filename:)
    File.open(bundle_path) do |file|
      bundle.bundle_file.attach(
        io: file,
        filename: filename,
        content_type: "application/x-rar-compressed"
      )
    end
  end

  def parsed_body
    Nokogiri::HTML(response.body)
  end

  def card_for(doc, name)
    doc.css("[data-filter-item]").find do |card|
      heading = card.at_css("h3")
      heading && heading.text.strip == name
    end
  end

  def link_in(card, label)
    card.css("a").find { |link| link.text.strip == label }
  end

  def button_in(card, label)
    card.css("button").find { |button| button.text.strip == label }
  end

  def chip_in(doc, label)
    doc.css("span[data-filter-default-class]").find { |chip| chip.text.strip == label }
  end

  it "renders the Expert Advisors index page with guide copy" do
    create(:user_expert_advisor, user:, expert_advisor:)

    get dashboard_expert_advisors_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.index.guide_copy", locale: :en))
  end

  it "renders guides for an active user EA" do
    create(:user_expert_advisor, user:, expert_advisor:)

    get dashboard_expert_advisor_guides_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("Sniper Advanced Panel")
  end

  it "renders the EA show page for a locked user" do
    get dashboard_expert_advisor_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.show.guide_copy", locale: :en))
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.license.locked_value", locale: :en))

    doc = parsed_body
    system_chip = chip_in(doc, I18n.t("dashboard.expert_advisors.show.system_status.locked", locale: :en))
    license_chip = chip_in(doc, I18n.t("dashboard.expert_advisors.status.locked", locale: :en))
    expect(system_chip).to be_present
    expect(license_chip).to be_present
    expect(system_chip["class"]).to include("border")
    expect(license_chip["class"]).to include("border")
    expect(system_chip["class"]).to include("dark:bg-gray-800")
    expect(license_chip["class"]).to include("dark:bg-gray-800")
  end

  it "renders the EA show page with license details when accessible" do
    license = create(:license, user: user, expert_advisor: expert_advisor, status: "active", last_synced_at: Time.utc(2025, 1, 20))
    create(:broker_account, license: license, company: "BrokerX", account_number: 987654)

    get dashboard_expert_advisor_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(license.encrypted_key)
    expect(response.body).to include("BrokerX")
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.show.values.broker_accounts_count", count: 1, locale: :en))

    doc = parsed_body
    system_chip = chip_in(doc, I18n.t("dashboard.expert_advisors.show.system_status.active", locale: :en))
    license_chip = chip_in(doc, I18n.t("dashboard.expert_advisors.status.active", locale: :en))
    expect(system_chip).to be_present
    expect(license_chip).to be_present
    expect(system_chip["class"]).to include("border")
    expect(license_chip["class"]).to include("border")

    copy_button = doc.at_css("button[data-copy-button='true']")
    expect(copy_button).to be_present
    expect(copy_button["data-copy-text"]).to eq(license.encrypted_key)
    expect(copy_button["data-copy-failed-text"]).to eq(I18n.t("dashboard.expert_advisors.copy_failed", locale: :en))
  end

  it "serves the complete rotated key without caching stale license credentials" do
    license = create(
      :license,
      user: user,
      expert_advisor: expert_advisor,
      status: "active",
      trial_ends_at: nil,
      expires_at: 1.month.from_now
    )
    previous_key = license.encrypted_key
    Licenses::RotateTokens.new(
      scope: :user,
      user: user,
      actor: create(:user, :admin),
      request_id: SecureRandom.uuid
    ).call

    get dashboard_expert_advisor_path(expert_advisor, locale: :en)

    license.reload
    doc = parsed_body
    key_value = doc.at_css("[data-license-value]")
    key_layout = doc.at_css("[data-license-key-layout]")
    copy_button = doc.at_css("button[data-copy-button='true']")
    expect(response).to be_successful
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(key_value.text.strip).to eq(license.encrypted_key)
    expect(key_value["class"]).to include("license-key-value")
    expect(key_layout["class"]).to include("grid")
    expect(copy_button["data-copy-text"]).to eq(license.encrypted_key)
    expect(response.body).not_to include(previous_key)
    expect(response.body).to include(
      I18n.t(
        "dashboard.expert_advisors.show.token_metadata_rotated",
        version: license.token_version,
        date: I18n.l(license.token_rotated_at, format: :short_with_year, locale: :en),
        locale: :en
      )
    )
  end

  it "shows lifetime expiration labels on index and show when the license is one-time" do
    create(:license, :one_time, user: user, expert_advisor: expert_advisor, status: "active")
    lifetime_label = I18n.t(
      "dashboard.expert_advisors.show.expires_on",
      date: I18n.l(License::LIFETIME_EXPIRES_AT, format: :short_with_year, locale: :en),
      locale: :en
    )

    get dashboard_expert_advisors_path(locale: :en)
    expect(response).to be_successful
    expect(response.body).to include(lifetime_label)

    get dashboard_expert_advisor_path(expert_advisor, locale: :en)
    expect(response).to be_successful
    expect(response.body).to include(lifetime_label)
  end

  it "returns not found when user does not own the EA" do
    get dashboard_expert_advisor_guides_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:not_found)
  end

  it "does not grant guides or downloads from a product role" do
    attach_bundle(expert_advisor)
    sign_out user

    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)
      sign_in role_user, scope: :user

      get dashboard_expert_advisor_guides_path(expert_advisor, locale: :en)
      expect(response).to have_http_status(:not_found)

      get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)
      expect(response).to redirect_to(dashboard_expert_advisors_path(locale: :en))
      expect(role_user.licenses).to be_empty

      sign_out role_user
    end
  end

  it "renders addon guides when user owns base access and addon purchase" do
    create(:license, user: user, expert_advisor: expert_advisor, status: "active")
    addon_product = create(
      :marketplace_product,
      title_en: "Trend Ride Add-on",
      summary_en: "Guide summary",
      description_en: "# Trend Ride Add-on\n\nGuide body."
    )
    addon = create(:addon, key: "addon_compound_trend_ride", addonable: expert_advisor, billing_plan: addon_product.billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: addon_product.billing_plan)

    get dashboard_expert_advisor_addon_guide_path(expert_advisor, addon_key: addon.key, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Trend Ride Add-on")
    expect(response.body).to include("Guide body.")
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.addon_guide_base_hint", base: expert_advisor.name, locale: :en))
  end

  it "returns not found for addon guide when addon purchase is missing" do
    create(:license, user: user, expert_advisor: expert_advisor, status: "active")
    addon_product = create(:marketplace_product)
    addon = create(:addon, key: "addon_compound_trend_ride", addonable: expert_advisor, billing_plan: addon_product.billing_plan)

    get dashboard_expert_advisor_addon_guide_path(expert_advisor, addon_key: addon.key, locale: :en)

    expect(response).to have_http_status(:not_found)
  end

  it "returns not found for addon guide when base access is missing" do
    addon_product = create(:marketplace_product)
    addon = create(:addon, key: "addon_compound_trend_ride", addonable: expert_advisor, billing_plan: addon_product.billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: addon_product.billing_plan)

    get dashboard_expert_advisor_addon_guide_path(expert_advisor, addon_key: addon.key, locale: :en)

    expect(response).to have_http_status(:not_found)
  end

  it "shows owned addon guides without retired marketplace purchase CTAs" do
    create(:license, user: user, expert_advisor: expert_advisor, status: "active")

    owned_product = create(:marketplace_product, title_en: "Owned Add-on")
    unowned_product = create(:marketplace_product, title_en: "Unowned Add-on")

    owned_addon = create(:addon, key: "addon_compound_trend_ride", addonable: expert_advisor, billing_plan: owned_product.billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: owned_product.billing_plan)
    create(:addon, key: "addon_compound_breakout_ready", addonable: expert_advisor, billing_plan: unowned_product.billing_plan)

    get dashboard_expert_advisor_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    doc = parsed_body

    addon_guide_link = doc.at_css("a[href='#{dashboard_expert_advisor_addon_guide_path(expert_advisor, addon_key: owned_addon.key, locale: :en)}']")
    addon_purchase_link = doc.css("a[href='#{dashboard_marketplace_product_path(unowned_product, locale: :en)}']")
                             .find { |link| link.text.include?(I18n.t("dashboard.expert_advisors.addons.purchase_cta", locale: :en)) }

    expect(addon_guide_link).to be_present
    expect(addon_guide_link.text).to include(I18n.t("dashboard.expert_advisors.addons.guide_cta", locale: :en))
    expect(addon_purchase_link).to be_nil
    expect(doc.text).not_to include("Unowned Add-on")
  end

  it "redirects to the bundle download when licensed" do
    create(:license, user:, expert_advisor:)
    attach_bundle(expert_advisor)

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expect(location).to include("/#{expert_advisor.ea_id}.rar")
    expect(location).not_to include("ea_bundle")
  end

  it "redirects to the matching expert advisor bundle when bundles exist" do
    create(:license, user:, expert_advisor:)
    bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    attach_ea_bundle(bundle, filename: "#{expert_advisor.ea_id}__base.rar")

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expect(location).to include("#{expert_advisor.ea_id}__base.rar")
  end

  it "falls back to the base bundle when addon-specific bundle is missing" do
    create(:license, user:, expert_advisor:)
    addon_product = create(:marketplace_product, title_en: "Trend Ride Add-on")
    addon = create(:addon, key: "addon_compound_trend_ride", addonable: expert_advisor, billing_plan: addon_product.billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    base_bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    attach_ea_bundle(base_bundle, filename: "#{expert_advisor.ea_id}__base.rar")

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expect(location).to include("#{expert_advisor.ea_id}__base.rar")
  end

  it "blocks bundle downloads when the matching bundle is missing" do
    create(:license, user:, expert_advisor:)
    create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/expert_advisors")
    expect(flash[:alert]).to eq(I18n.t("dashboard.expert_advisors.bundle_missing"))
  end

  it "blocks bundle download when locked" do
    attach_bundle(expert_advisor)

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/expert_advisors")
  end

  it "orders expert advisors by tier_rank then name" do
    tiered = [
      create(:expert_advisor, name: "Sniper Advanced Panel", tier_rank: 1),
      create(:expert_advisor, name: "Pandora Box", tier_rank: 2),
      create(:expert_advisor, name: "XAU HFT Scalper", tier_rank: 3)
    ]

    get dashboard_expert_advisors_path(locale: :en)

    positions = tiered.map { |ea| response.body.index(ea.name) }
    expect(positions).to all(be_present)
    expect(positions).to eq(positions.sort)
  end

  it "renders tag filter chips for the top tags" do
    ea1 = create(:expert_advisor, name: "EA Alpha")
    ea2 = create(:expert_advisor, name: "EA Beta")
    ea3 = create(:expert_advisor, name: "EA Gamma")
    ea4 = create(:expert_advisor, name: "EA Delta")
    ea5 = create(:expert_advisor, name: "EA Epsilon")
    ea6 = create(:expert_advisor, name: "EA Zeta")

    ea1.tag_list.add("alpha", "beta")
    ea2.tag_list.add("alpha", "gamma")
    ea3.tag_list.add("alpha")
    ea4.tag_list.add("delta")
    ea5.tag_list.add("epsilon")
    ea6.tag_list.add("zeta")
    [ ea1, ea2, ea3, ea4, ea5, ea6 ].each(&:save!)

    get dashboard_expert_advisors_path(locale: :en)

    doc = parsed_body
    chips = doc.css("[data-filter-tag]")
    values = chips.map { |chip| chip["data-filter-tag"] }

    expect(doc.at_css("[data-filter-all]")).to be_present
    expect(chips.size).to eq(5)
    expect(values).to include("alpha", "beta", "gamma", "delta", "epsilon")
    expect(values).not_to include("zeta")
  end

  it "paginates cards and toggles visibility by page" do
    names = ("A".."I").map { |letter| "EA #{letter}" }
    names.each { |name| create(:expert_advisor, name: name) }

    get dashboard_expert_advisors_path(locale: :en)

    doc = parsed_body
    expect(doc.at_css("[data-filter-pagination]")).to be_present

    first_card = card_for(doc, names.first)
    last_card = card_for(doc, names.last)
    expect(first_card["class"].split).not_to include("hidden")
    expect(last_card["class"].split).to include("hidden")

    get dashboard_expert_advisors_path(locale: :en, page: 2)

    doc = parsed_body
    first_card = card_for(doc, names.first)
    last_card = card_for(doc, names.last)
    expect(first_card["class"].split).to include("hidden")
    expect(last_card["class"].split).not_to include("hidden")
  end

  it "omits pagination when there are 8 or fewer cards" do
    create_list(:expert_advisor, 8)

    get dashboard_expert_advisors_path(locale: :en)

    doc = parsed_body
    expect(doc.at_css("[data-filter-pagination]")).to be_nil
  end

  it "renders CTA states for accessible and locked expert advisors" do
    accessible_ea = create(:expert_advisor, name: "Accessible EA")
    locked_marketplace_ea = create(:expert_advisor, name: "Marketplace Locked EA")
    locked_plan_ea = create(:expert_advisor, name: "Plan Locked EA")

    license = create(:license, user: user, expert_advisor: accessible_ea, status: "active")
    attach_bundle(accessible_ea)

    subscription_plan = create(
      :billing_plan,
      tier: Billing::PandoraPricing::TIER,
      amount_cents: Billing::PandoraPricing::MONTHLY_CENTS
    )
    create(:billing_plan_entitlement, billing_plan: subscription_plan, expert_advisor: locked_plan_ea)

    product_plan = create(:billing_plan, :one_time)
    marketplace_product = create(:marketplace_product, billing_plan: product_plan)
    create(:billing_plan_entitlement, billing_plan: product_plan, expert_advisor: locked_marketplace_ea)

    owned_plan = create(:billing_plan, :one_time)
    owned_product = create(:marketplace_product, billing_plan: owned_plan)
    create(:addon, addonable: accessible_ea, billing_plan: owned_plan)
    create(:marketplace_purchase, user: user, billing_plan: owned_plan)

    unowned_plan = create(:billing_plan, :one_time)
    unowned_product = create(:marketplace_product, billing_plan: unowned_plan)
    create(:addon, addonable: accessible_ea, billing_plan: unowned_plan)

    extra_plan = create(:billing_plan, :one_time)
    extra_product = create(:marketplace_product, billing_plan: extra_plan)
    create(:addon, addonable: accessible_ea, billing_plan: extra_plan)

    get dashboard_expert_advisors_path(locale: :en)

    doc = parsed_body
    guide_label = I18n.t("dashboard.expert_advisors.guide_cta", locale: :en)
    unlock_label = I18n.t("dashboard.expert_advisors.unlock_cta", locale: :en)
    details_label = I18n.t("dashboard.expert_advisors.show_cta", locale: :en)
    download_label = I18n.t("dashboard.expert_advisors.download_bundle", locale: :en)
    purchase_label = I18n.t("dashboard.expert_advisors.addons.purchase_cta", locale: :en)
    owned_label = I18n.t("dashboard.expert_advisors.addons.owned_cta", locale: :en)
    copy_label = I18n.t("dashboard.expert_advisors.copy_code", locale: :en)
    copy_failed_label = I18n.t("dashboard.expert_advisors.copy_failed", locale: :en)
    locked_license = I18n.t("dashboard.expert_advisors.license.locked_value", locale: :en)
    addons_progress = I18n.t("dashboard.expert_advisors.addons.progress", owned: 1, total: 1, locale: :en)
    zero_progress = I18n.t("dashboard.expert_advisors.addons.progress", owned: 0, total: 0, locale: :en)

    accessible_card = card_for(doc, accessible_ea.name)
    expect(link_in(accessible_card, guide_label)["href"])
      .to eq(dashboard_expert_advisor_guides_path(accessible_ea, locale: :en))
    license_value = accessible_card.at_css("[data-license-value]")
    expect(license_value).to be_present
    expect(license_value.text).to include(license.encrypted_key)
    expect(link_in(accessible_card, details_label)["href"])
      .to eq(dashboard_expert_advisor_path(accessible_ea, locale: :en))
    expect(link_in(accessible_card, download_label)["href"])
      .to eq(dashboard_expert_advisor_download_path(accessible_ea, locale: :en))
    expect(accessible_card.text).to include(addons_progress)
    expect(accessible_card.css("a").any? { |link| link.text.strip == purchase_label }).to be(false)
    expect(accessible_card.css("button").any? { |button| button.text.strip == owned_label }).to be(true)
    expect(accessible_card.text).not_to include(unowned_product.title_en)
    expect(accessible_card.text).not_to include(extra_product.title_en)
    guide_actions_row = accessible_card.at_css("[data-guide-actions-row]")
    expect(guide_actions_row).to be_present
    expect(guide_actions_row["class"]).to include("flex")
    expect(link_in(guide_actions_row, guide_label)["href"])
      .to eq(dashboard_expert_advisor_guides_path(accessible_ea, locale: :en))
    expect(link_in(guide_actions_row, details_label)["href"])
      .to eq(dashboard_expert_advisor_path(accessible_ea, locale: :en))
    copy_button = button_in(accessible_card, copy_label)
    expect(copy_button["data-copy-text"]).to eq(license.encrypted_key)
    expect(copy_button["data-copy-button"]).to eq("true")
    expect(copy_button["data-copy-failed-text"]).to eq(copy_failed_label)
    expect(copy_button["disabled"]).to be_nil

    marketplace_card = card_for(doc, locked_marketplace_ea.name)
    expect(link_in(marketplace_card, unlock_label)["href"])
      .to eq(dashboard_plans_path(locale: :en))
    download_button = button_in(marketplace_card, download_label)
    expect(download_button["disabled"]).to eq("disabled")
    expect(marketplace_card.text).to include(locked_license)
    expect(marketplace_card.at_css("[data-license-value]").text).to include(locked_license)
    locked_copy_button = button_in(marketplace_card, copy_label)
    expect(locked_copy_button["disabled"]).to eq("disabled")
    expect(locked_copy_button["data-copy-button"]).to be_nil
    expect(locked_copy_button["data-copy-text"]).to be_nil

    plan_card = card_for(doc, locked_plan_ea.name)
    expect(link_in(plan_card, unlock_label)["href"])
      .to eq(dashboard_plans_path(locale: :en, price_key: subscription_plan.key))
    expect(plan_card.text).to include(zero_progress)
  end
end
