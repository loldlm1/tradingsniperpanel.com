require "rails_helper"
require "securerandom"

RSpec.describe Addons::Eligibility do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Core EA", ea_id: "core-ea") }
  let(:addon) { create(:addon, key: "news_filter", addonable: expert_advisor) }

  def create_subscription(user:, plan:, status: "active", trial_ends_at: nil)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: status,
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now,
      trial_ends_at: trial_ends_at
    )
  end

  describe "expert advisor add-ons" do
    it "allows privileged users without base purchases" do
      privileged_user = create(:user, :full_trader)

      result = described_class.new(user: privileged_user, addon: addon).call

      expect(result).to be_allowed
    end

    it "allows one-time licenses" do
      create(:license, :one_time, user: user, expert_advisor: expert_advisor)

      result = described_class.new(user: user, addon: addon).call

      expect(result).to be_allowed
    end

    it "blocks trial licenses" do
      create(:license, user: user, expert_advisor: expert_advisor, status: "trial")

      result = described_class.new(user: user, addon: addon).call

      expect(result.allowed?).to be(false)
      expect(result.reason).to eq(:base_trial)
    end

    it "blocks subscription trialing access" do
      create(:license, user: user, expert_advisor: expert_advisor, status: "active", access_source: "subscription", trial_ends_at: nil)
      plan = create(:billing_plan, tier: "basic")
      create_subscription(user: user, plan: plan, status: "trialing", trial_ends_at: 7.days.from_now)

      result = described_class.new(user: user, addon: addon).call

      expect(result.allowed?).to be(false)
      expect(result.reason).to eq(:base_trial)
    end

    it "allows paid subscriptions" do
      create(:license, user: user, expert_advisor: expert_advisor, status: "active", access_source: "subscription", trial_ends_at: nil)
      plan = create(:billing_plan, tier: "basic")
      create_subscription(user: user, plan: plan, status: "active")

      result = described_class.new(user: user, addon: addon).call

      expect(result).to be_allowed
    end
  end

  describe "course add-ons" do
    let(:course) { create(:course, slug: "intro-course") }
    let(:course_addon) { create(:addon, key: "workbook", addonable: course) }

    it "allows one-time enrollments" do
      create(:course_enrollment, :one_time, user: user, course: course)

      result = described_class.new(user: user, addon: course_addon).call

      expect(result).to be_allowed
    end

    it "allows paid subscriptions with matching tier entitlements" do
      plan = create(:billing_plan, tier: "basic")
      create(:course_plan_entitlement, course: course, billing_plan: plan)
      create_subscription(user: user, plan: plan, status: "active")

      result = described_class.new(user: user, addon: course_addon).call

      expect(result).to be_allowed
    end

    it "blocks paid subscriptions without entitlement" do
      plan = create(:billing_plan, tier: "basic")
      create(:course_plan_entitlement, course: course, billing_plan: create(:billing_plan, tier: "pro"))
      create_subscription(user: user, plan: plan, status: "active")

      result = described_class.new(user: user, addon: course_addon).call

      expect(result.allowed?).to be(false)
      expect(result.reason).to eq(:missing_base)
    end

    it "allows privileged users without course entitlements" do
      privileged_user = create(:user, :full_trader)

      result = described_class.new(user: privileged_user, addon: course_addon).call

      expect(result).to be_allowed
    end
  end

  describe "asset add-ons" do
    let(:asset) { create(:marketplace_asset, slug: "rules-guide") }
    let(:asset_addon) { create(:addon, key: "bonus_pack", addonable: asset) }

    it "allows access when the asset is purchased" do
      base_plan = create(:billing_plan, :one_time)
      create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: base_plan)
      create(:marketplace_purchase, user: user, billing_plan: base_plan)

      result = described_class.new(user: user, addon: asset_addon).call

      expect(result).to be_allowed
    end

    it "blocks access when the asset is not purchased" do
      base_plan = create(:billing_plan, :one_time)
      create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: base_plan)

      result = described_class.new(user: user, addon: asset_addon).call

      expect(result.allowed?).to be(false)
      expect(result.reason).to eq(:missing_base)
    end

    it "allows privileged users without asset purchases" do
      privileged_user = create(:user, :full_trader)

      result = described_class.new(user: privileged_user, addon: asset_addon).call

      expect(result).to be_allowed
    end
  end
end
