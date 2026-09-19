require "rails_helper"
require "securerandom"

RSpec.describe Licenses::BackfillPanelSubscriptionLicenses do
  include ActiveSupport::Testing::TimeHelpers

  let!(:catalog) { create_subscription_catalog }
  let(:panel) { catalog.fetch(:expert_advisors).fetch("sniper_advanced_panel") }
  let(:chu) { catalog.fetch(:expert_advisors).fetch("chu_sniper_trailing") }
  let(:encoder) { Licenses::LicenseKeyEncoder.new }

  before { travel_to Time.utc(2026, 9, 19, 12) }
  after { travel_back }

  it "issues a distinct, three-field Panel key for Chu and Pandora Stripe and manual subscribers" do
    users = []
    [ :chu_monthly, :pandora_annual ].each do |plan_key|
      plan = catalog.fetch(plan_key)
      stripe_user = create(:user)
      manual_user = create(:user, :admin)
      create_pay_subscription(user: stripe_user, plan: plan)
      create(:manual_subscription, user: manual_user, billing_plan: plan)
      users.concat([ stripe_user, manual_user ])
    end

    result = described_class.new(dry_run: false, batch_size: 1).call

    expect(result).to have_attributes(scanned: 4, eligible: 4, created: 4, failed: 0)
    users.each do |user|
      license = License.find_by!(user: user, expert_advisor: panel)
      expect(license).to be_active
      expect(encoder.decrypt(license.encrypted_key).split(",")).to eq(
        [ user.email, "sniper_advanced_panel", license.expires_at.to_i.to_s ]
      )
      expect(license.encrypted_key).not_to eq(
        encoder.generate(email: user.email, ea_id: chu.ea_id, expires_at: license.expires_at)
      )
    end
  end

  it "supports dry-run and repeated apply without changing existing Chu or Pandora keys" do
    user = create(:user)
    create_pay_subscription(user: user, plan: catalog.fetch(:pandora_monthly))
    originals = [ chu, catalog.fetch(:expert_advisors).fetch("pandora_box") ].map do |ea|
      create(:license, user: user, expert_advisor: ea, token_version: 2, token_rotated_at: 1.day.ago)
    end
    attributes = originals.map(&:attributes)

    expect { described_class.new.call }.not_to change(License, :count)
    result = described_class.new(dry_run: false).call
    license = License.find_by!(user: user, expert_advisor: panel)
    panel_attributes = license.attributes
    repeated = described_class.new(dry_run: false).call

    expect(result.created).to eq(1)
    expect(repeated).to have_attributes(unchanged: 1, created: 0, repaired: 0, failed: 0)
    expect(license.reload.attributes).to eq(panel_attributes)
    expect(originals.map { |record| record.reload.attributes }).to eq(attributes)
  end

  it "repairs a retired Panel license only for a currently entitled subscriber" do
    user = create(:user)
    create_pay_subscription(user: user, plan: catalog.fetch(:chu_monthly))
    old = create(:license, user: user, expert_advisor: panel, status: "expired", expires_at: 1.day.ago)
    old_key = old.encrypted_key

    result = described_class.new(dry_run: false).call

    expect(result.repaired).to eq(1)
    expect(old.reload).to have_attributes(status: "active", source: "stripe_subscription", token_version: 1)
    expect(old.encrypted_key).not_to eq(old_key)
  end

  it "does not grant access through an admin role, expired subscription, future grant, or old Panel key" do
    admin = create(:user, :admin)
    expired = create(:user)
    future = create(:user)
    legacy = create(:user)
    create_pay_subscription(user: expired, plan: catalog.fetch(:chu_monthly), period_end: 1.day.ago)
    create(:manual_subscription, user: future, billing_plan: catalog.fetch(:chu_monthly), starts_at: 1.day.from_now, ends_at: 10.days.from_now)
    old = create(:license, user: legacy, expert_advisor: panel, status: "expired", expires_at: 1.day.ago)

    result = described_class.new(dry_run: false).call

    expect(result.created).to eq(0)
    expect(License.where(user: [ admin, expired, future ], expert_advisor: panel)).to be_empty
    expect(old.reload).to be_expired
  end

  it "uses the complete contiguous manual period just like the ordinary license sync" do
    user = create(:user)
    plan = catalog.fetch(:chu_monthly)
    current = create(:manual_subscription, user: user, billing_plan: plan, ends_at: 5.days.from_now)
    following = create(:manual_subscription, user: user, billing_plan: plan, starts_at: current.ends_at, ends_at: 15.days.from_now)
    Licenses::ManualSubscriptionSync.new(manual_subscription_id: current.id).call
    License.find_by!(user: user, expert_advisor: panel).destroy!

    described_class.new(dry_run: false).call

    license = License.find_by!(user: user, expert_advisor: panel)
    expect(license.expires_at).to eq(following.ends_at)
    expect(license.expires_at).to eq(License.find_by!(user: user, expert_advisor: chu).expires_at)
  end

  it "fails closed when the Panel entitlement is missing from a canonical plan" do
    user = create(:user)
    plan = catalog.fetch(:chu_monthly)
    create_pay_subscription(user: user, plan: plan)
    BillingPlanEntitlement.find_by!(billing_plan: plan, expert_advisor: panel).destroy!

    result = described_class.new(dry_run: false).call

    expect(result.created).to eq(0)
    expect(License.find_by(user: user, expert_advisor: panel)).to be_nil
  end

  it "continues after a per-user failure and can retry without duplicating grants" do
    users = create_list(:user, 2)
    users.each { |user| create_pay_subscription(user: user, plan: catalog.fetch(:chu_monthly)) }
    failing_encoder = Licenses::LicenseKeyEncoder.new
    allow(failing_encoder).to receive(:generate).and_wrap_original do |method, **attributes|
      raise "temporary failure" if attributes.fetch(:email) == users.first.email

      method.call(**attributes)
    end

    failed = described_class.new(dry_run: false, encoder: failing_encoder).call
    retried = described_class.new(dry_run: false).call

    expect(failed).to have_attributes(created: 1, failed: 1, failed_user_ids: [ users.first.id ])
    expect(retried).to have_attributes(created: 1, unchanged: 1, failed: 0)
    expect(License.where(expert_advisor: panel).count).to eq(2)
  end

  def create_pay_subscription(user:, plan:, period_end: 1.month.from_now)
    customer = user.pay_customers.create!(processor: "stripe", processor_id: "cus_#{SecureRandom.hex(4)}", default: true)
    customer.subscriptions.create!(
      name: "default", processor_id: "sub_#{SecureRandom.hex(4)}", processor_plan: plan.stripe_price_id,
      status: "active", quantity: 1, current_period_start: Time.current, current_period_end: period_end
    )
  end
end
