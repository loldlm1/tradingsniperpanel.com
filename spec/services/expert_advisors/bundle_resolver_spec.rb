require "rails_helper"

RSpec.describe ExpertAdvisors::BundleResolver do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, ea_id: "ea-bundle") }
  let(:bundle_path) { Rails.root.join("spec/fixtures/files/ea_bundle.rar") }

  def attach_bundle(bundle, filename:)
    File.open(bundle_path) do |file|
      bundle.bundle_file.attach(
        io: file,
        filename: filename,
        content_type: "application/x-rar-compressed"
      )
    end
  end

  it "returns the base bundle when no addons are purchased" do
    bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    attach_bundle(bundle, filename: "#{expert_advisor.ea_id}__base.rar")

    result = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(result).to be_found
    expect(result.bundle).to eq(bundle)
    expect(result.bundle_key).to eq("base")
    expect(result.addon_keys).to eq([])
  end

  it "returns the matching addon bundle" do
    addon_one = create(:addon, key: "news_filter", addonable: expert_advisor)
    addon_two = create(:addon, key: "moving_average_filter", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon_one.billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: addon_two.billing_plan)

    bundle = create(
      :expert_advisor_bundle,
      expert_advisor: expert_advisor,
      bundle_key: "moving_average_filter__news_filter",
      required_addon_keys: "news_filter,moving_average_filter"
    )
    attach_bundle(bundle, filename: "#{expert_advisor.ea_id}__moving_average_filter__news_filter.rar")

    result = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(result).to be_found
    expect(result.bundle).to eq(bundle)
    expect(result.bundle_key).to eq("moving_average_filter__news_filter")
    expect(result.addon_keys).to eq(%w[moving_average_filter news_filter])
  end

  it "marks missing bundles when none match" do
    addon = create(:addon, key: "news_filter", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    result = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(result.found?).to be(false)
    expect(result.missing_bundle).to be(true)
    expect(result.bundle_key).to eq("news_filter")
  end

  it "falls back to the base bundle when an addon-specific bundle is missing" do
    addon = create(:addon, key: "news_filter", addonable: expert_advisor)
    create(:marketplace_purchase, user: user, billing_plan: addon.billing_plan)

    base_bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    attach_bundle(base_bundle, filename: "#{expert_advisor.ea_id}__base.rar")

    result = described_class.new(user: user, expert_advisor: expert_advisor).call

    expect(result).to be_found
    expect(result.bundle).to eq(base_bundle)
    expect(result.bundle_key).to eq("base")
    expect(result.addon_keys).to eq(["news_filter"])
  end

  it "returns only the base bundle for product roles without add-on purchases" do
    create(:addon, key: "news_filter", addonable: expert_advisor)
    create(:addon, key: "moving_average_filter", addonable: expert_advisor)

    base_bundle = create(
      :expert_advisor_bundle,
      expert_advisor: expert_advisor,
      bundle_key: "base",
      required_addon_keys: ""
    )
    attach_bundle(base_bundle, filename: "#{expert_advisor.ea_id}__base.rar")
    addon_bundle = create(
      :expert_advisor_bundle,
      expert_advisor: expert_advisor,
      bundle_key: "moving_average_filter__news_filter",
      required_addon_keys: "news_filter,moving_average_filter"
    )
    attach_bundle(addon_bundle, filename: "#{expert_advisor.ea_id}__moving_average_filter__news_filter.rar")

    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)
      result = described_class.new(user: role_user, expert_advisor: expert_advisor).call

      expect(result).to be_found
      expect(result.bundle).to eq(base_bundle)
      expect(result.addon_keys).to eq([])
    end
  end
end
