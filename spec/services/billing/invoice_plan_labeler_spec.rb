require "rails_helper"
require "ostruct"

RSpec.describe Billing::InvoicePlanLabeler do
  around do |example|
    original_env = ENV.to_hash
    ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "price_basic_monthly"
    ENV["STRIPE_PRICE_HFT_MONTHLY"] = "price_hft_monthly"
    ENV["STRIPE_PRICE_PRO_MONTHLY"] = "price_pro_monthly"
    ENV["STRIPE_PRIVATE_KEY"] = "sk_test_123"
    example.run
  ensure
    ENV.replace(original_env)
  end

  def build_charge(invoice_id: "in_123")
    OpenStruct.new(data: { "stripe_invoice" => { "id" => invoice_id } })
  end

  def build_stripe_invoice(lines)
    OpenStruct.new(lines: OpenStruct.new(data: lines))
  end

  it "labels a single plan invoice" do
    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: 1200, price: OpenStruct.new(id: "price_basic_monthly"))
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end

  it "labels an upgrade invoice with from/to plans" do
    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: -500, price: OpenStruct.new(id: "price_basic_monthly")),
      OpenStruct.new(amount: 1500, price: OpenStruct.new(id: "price_hft_monthly"))
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

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
    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: -2000, price: OpenStruct.new(id: "price_hft_monthly")),
      OpenStruct.new(amount: 500, price: OpenStruct.new(id: "price_basic_monthly"))
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

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

  it "falls back when no price ids are found" do
    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: 1000)
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice, fallback_label: "Fallback")

    expect(label).to eq("Fallback")
  end

  it "uses product ids when price ids do not map" do
    ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "prod_basic"

    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: 1200, price: OpenStruct.new(id: "price_unknown", product: "prod_basic"))
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end

  it "extracts nested product ids from price hashes" do
    ENV["STRIPE_PRICE_BASIC_MONTHLY"] = "prod_basic"

    invoice = build_charge
    stripe_invoice = build_stripe_invoice([
      OpenStruct.new(amount: 1200, price: OpenStruct.new(id: "price_unknown", product: OpenStruct.new(id: "prod_basic")))
    ])

    allow(Stripe::Invoice).to receive(:retrieve).and_return(stripe_invoice)

    label = described_class.new.label_for(invoice)

    expected = I18n.t(
      "dashboard.plan_card.plan_label",
      tier: I18n.t("dashboard.plans.tiers.basic.name"),
      interval: I18n.t("dashboard.plans.toggle.monthly")
    )

    expect(label).to eq(expected)
  end
end
