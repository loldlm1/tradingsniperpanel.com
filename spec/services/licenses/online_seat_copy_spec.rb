require "rails_helper"

RSpec.describe Licenses::OnlineSeatCopy do
  it "builds subscription seat copy from tier order" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, sort_order: 1)
    create(:billing_plan, tier: "pro", key: "pro_monthly", interval: "month", interval_count: 1, sort_order: 2)

    basic_copy = described_class.subscription_feature_for_tier("basic", locale: :en)
    pro_copy = described_class.subscription_feature_for_tier("pro", locale: :en)

    expect(basic_copy).to eq(I18n.t("licenses.online_seats.subscription_feature", count: 5, locale: :en))
    expect(pro_copy).to eq(I18n.t("licenses.online_seats.subscription_feature", count: 6, locale: :en))
  end

  it "returns nil for tiers that are not in the active subscription order" do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, sort_order: 1)

    expect(described_class.subscription_feature_for_tier("enterprise", locale: :en)).to be_nil
  end

  it "builds one-time seat copy from the fixed cap constant" do
    expect(described_class.one_time_feature(locale: :en)).to eq(
      I18n.t("licenses.online_seats.one_time_feature", count: 8, locale: :en)
    )
  end
end
