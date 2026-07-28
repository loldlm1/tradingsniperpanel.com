require "rails_helper"
require "ostruct"

RSpec.describe Billing::InvoicePlanLabeler do
  let!(:basic_plan) do
    create(:billing_plan, tier: "basic", key: "basic_monthly", interval: "month", interval_count: 1, amount_cents: 1000, stripe_price_id: "price_basic_monthly", stripe_product_id: "prod_basic")
  end
  let!(:hft_plan) do
    create(:billing_plan, tier: "hft", key: "hft_monthly", interval: "month", interval_count: 1, amount_cents: 2000, stripe_price_id: "price_hft_monthly")
  end

  around do |example|
    original_env = ENV.to_hash
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV.replace(original_env)
  end

  def build_charge(lines: nil, invoice_id: "in_123")
    data = { "stripe_invoice" => { "id" => invoice_id } }
    if lines
      data["stripe_invoice"]["lines"] = { "data" => lines }
    end
    OpenStruct.new(data: data)
  end

  def pricing_line(amount:, price_id:, product_id: nil)
    {
      "amount" => amount,
      "pricing" => {
        "type" => "price_details",
        "price_details" => {
          "price" => price_id,
          "product" => product_id
        }
      }
    }
  end

  it "labels a single plan invoice from stored pricing details" do
    invoice = build_charge(lines: [ pricing_line(amount: 1200, price_id: "price_basic_monthly") ])

    expect(Stripe::Invoice).not_to receive(:retrieve)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end

  it "labels an upgrade invoice with from/to plans" do
    invoice = build_charge(
      lines: [
        pricing_line(amount: -500, price_id: "price_basic_monthly"),
        pricing_line(amount: 1500, price_id: "price_hft_monthly")
      ]
    )

    expect(Stripe::Invoice).not_to receive(:retrieve)

    label = described_class.new.label_for(invoice)

    from_label = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )
    to_label = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.hft.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expected = I18n.t(
      "dashboard.billing.invoice_plan_change",
      from: from_label,
      to: to_label,
      change: I18n.t("dashboard.billing.invoice_change_upgrade")
    )

    expect(label).to eq(expected)
  end

  it "labels a downgrade invoice with from/to plans" do
    invoice = build_charge(
      lines: [
        pricing_line(amount: -2000, price_id: "price_hft_monthly"),
        pricing_line(amount: 500, price_id: "price_basic_monthly")
      ]
    )

    expect(Stripe::Invoice).not_to receive(:retrieve)

    label = described_class.new.label_for(invoice)

    from_label = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.hft.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )
    to_label = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expected = I18n.t(
      "dashboard.billing.invoice_plan_change",
      from: from_label,
      to: to_label,
      change: I18n.t("dashboard.billing.invoice_change_downgrade")
    )

    expect(label).to eq(expected)
  end

  it "falls back when no plan lines are detected" do
    invoice = build_charge(lines: [ { "amount" => 1000 } ])
    stripe_invoice = OpenStruct.new(lines: OpenStruct.new(data: [ { "amount" => 1000 } ]))

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice, fallback_label: "Fallback")

    expect(label).to eq("Fallback")
  end

  it "uses product ids when price ids do not map" do
    invoice = build_charge(
      lines: [ pricing_line(amount: 1200, price_id: "price_unknown", product_id: "prod_basic") ]
    )

    expect(Stripe::Invoice).not_to receive(:retrieve)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end

  it "labels invoices that reference a retired historical price" do
    retired = create(
      :billing_plan_price,
      billing_plan: basic_plan,
      stripe_price_id: "price_basic_retired",
      amount_cents: 750,
      active: false,
      retired_at: Time.current
    )
    invoice = build_charge(lines: [ pricing_line(amount: retired.amount_cents, price_id: retired.stripe_price_id) ])

    expect(Stripe::Invoice).not_to receive(:retrieve)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )
    expect(label).to eq(expected)
  end

  it "labels the canonical 4x4 transition matrix with product-aware directions" do
    catalog = create_subscription_catalog
    plans = catalog[:plans].values

    plans.product(plans).each do |from_plan, to_plan|
      next if from_plan == to_plan

      invoice = build_charge(
        lines: [
          pricing_line(amount: -100, price_id: from_plan.stripe_price_id),
          pricing_line(amount: 50, price_id: to_plan.stripe_price_id)
        ],
        invoice_id: "in_#{from_plan.id}_#{to_plan.id}"
      )
      direction = Billing::PlanComparator.new.compare(current_key: from_plan.key, target_key: to_plan.key)
      direction_label = I18n.t(
        direction == :downgrade ? "dashboard.billing.invoice_change_downgrade" : "dashboard.billing.invoice_change_upgrade"
      )

      expect(described_class.new.label_for(invoice)).to eq(
        I18n.t(
          "dashboard.billing.invoice_plan_change",
          from: expected_plan_label(from_plan),
          to: expected_plan_label(to_plan),
          change: direction_label
        )
      )
    end
  end

  it "uses catalog rank instead of raw totals when canonical proration lines have the same sign" do
    catalog = create_subscription_catalog
    invoice = build_charge(
      lines: [
        pricing_line(amount: 15_592, price_id: catalog[:chu_annual].stripe_price_id),
        pricing_line(amount: 7_900, price_id: catalog[:pandora_monthly].stripe_price_id)
      ]
    )

    label = described_class.new.label_for(invoice)

    expect(label).to eq(
      I18n.t(
        "dashboard.billing.invoice_plan_change",
        from: expected_plan_label(catalog[:chu_annual]),
        to: expected_plan_label(catalog[:pandora_monthly]),
        change: I18n.t("dashboard.billing.invoice_change_upgrade")
      )
    )
  end

  it "prefers an exact price id over an ambiguous product id" do
    catalog = create_subscription_catalog
    invoice = build_charge(
      lines: [
        pricing_line(
          amount: catalog[:pandora_annual].amount_cents,
          price_id: catalog[:pandora_annual].stripe_price_id,
          product_id: catalog[:pandora_monthly].stripe_product_id
        )
      ]
    )

    expect(described_class.new.label_for(invoice)).to eq(expected_plan_label(catalog[:pandora_annual]))
  end

  it "fetches Stripe invoice when stored lines are missing" do
    invoice = build_charge
    stripe_invoice = OpenStruct.new(
      lines: OpenStruct.new(
        data: [ pricing_line(amount: 1200, price_id: "price_basic_monthly") ]
      )
    )

    expect(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end

  def expected_plan_label(plan)
    I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.#{plan.tier}.name", default: plan.tier.humanize),
      interval: Billing::IntervalLabeler.label(interval: plan.interval, interval_count: plan.interval_count)
    )
  end
end
