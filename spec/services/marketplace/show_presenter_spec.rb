require "rails_helper"
require "securerandom"

RSpec.describe Marketplace::ShowPresenter do
  let(:user) { create(:user) }
  let(:expert_advisor) { create(:expert_advisor, name: "Alpha EA") }

  def create_base_product_for(expert_advisor:, amount_cents: 2500, title: "Base Bundle")
    base_plan = create(:billing_plan, :one_time, amount_cents: amount_cents)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: title)
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)
    [base_plan, base_product]
  end

  def create_active_subscription(user:, tier: "basic")
    plan = create(:billing_plan, tier: tier)
    customer = user.pay_customers.create!(
      processor: "stripe",
      processor_id: "cus_#{SecureRandom.hex(4)}",
      default: true
    )
    customer.subscriptions.create!(
      name: "default",
      processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: plan.stripe_price_id,
      status: "active",
      quantity: 1,
      current_period_start: Time.current,
      current_period_end: 1.month.from_now
    )
  end

  it "selects the first base product for add-on entries and preselects the add-on" do
    base_plan_one = create(:billing_plan, :one_time)
    base_product_one = create(:marketplace_product, billing_plan: base_plan_one, sort_order: 0, title_en: "Base One")
    create(:billing_plan_entitlement, billing_plan: base_plan_one, expert_advisor: expert_advisor)

    base_plan_two = create(:billing_plan, :one_time)
    base_product_two = create(:marketplace_product, billing_plan: base_plan_two, sort_order: 2, title_en: "Base Two")
    create(:billing_plan_entitlement, billing_plan: base_plan_two, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time, key: "addon_plan")
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Addon Pack")

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: addon_product.slug)

    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.base_product).to eq(base_product_one)
    expect(presenter.addon_rows.map(&:plan_key)).to include(addon_plan.key)
    expect(presenter.selected_addon_keys).to include(addon_plan.key)
    expect(presenter.base_product).not_to eq(base_product_two)
  end

  it "hides already owned add-ons from the list" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time)
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Owned Addon")
    create(:marketplace_purchase, user: user, billing_plan: addon_plan)

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: base_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.addon_rows.map(&:plan_key)).not_to include(addon_plan.key)
  end

  it "shows unowned add-ons to every product role" do
    base_plan = create(:billing_plan, :one_time)
    base_product = create(:marketplace_product, billing_plan: base_plan, title_en: "Base")
    create(:billing_plan_entitlement, billing_plan: base_plan, expert_advisor: expert_advisor)

    addon_plan = create(:billing_plan, :one_time)
    create(:addon, addonable: expert_advisor, billing_plan: addon_plan)
    create(:marketplace_product, billing_plan: addon_plan, title_en: "Role Addon")

    %i[admin master_admin full_trader].each do |role|
      role_user = create(:user, role: role)
      entry = Marketplace::Catalog.new(user: role_user).entry_for!(slug: base_product.slug)
      presenter = described_class.new(user: role_user, entry: entry, locale: :en).call

      expect(presenter.addon_rows.map(&:plan_key)).to eq([ addon_plan.key ])
    end
  end

  it "computes cart totals when the base product is required" do
    base_plan, base_product = create_base_product_for(expert_advisor: expert_advisor, amount_cents: 4500)

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: base_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.base_required?).to be(true)
    expect(presenter.addon_total_cents).to eq(0)
    expect(presenter.cart_total_cents).to eq(base_plan.amount_cents)
    expect(presenter.add_on_progress).to eq(total: 0, selected: 0, percent: 0)
    expect(presenter.online_seat_feature).to eq(
      I18n.t("licenses.online_seats.one_time_feature", count: 8, locale: :en)
    )
  end

  it "does not expose one-time seat copy for non-EA products" do
    course = create(:course, title_en: "Course")
    course_plan = create(:billing_plan, :one_time)
    course_product = create(:marketplace_product, billing_plan: course_plan, title_en: "Course Bundle")
    create(:course_plan_entitlement, billing_plan: course_plan, course: course)

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: course_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.online_seat_feature).to be_nil
  end

  it "supports direct addon pages when base access comes from subscription and no base product exists" do
    expert_advisor.update!(allowed_subscription_tiers: %w[basic])
    addon_plan = create(:billing_plan, :one_time, amount_cents: 19_900, key: "addon_fibonacci_compound_reversal_early")
    create(:addon, key: "addon_compound_reversal_early", addonable: expert_advisor, billing_plan: addon_plan)
    addon_product = create(:marketplace_product, billing_plan: addon_plan, title_en: "Compound Mode - Reversal Early")
    create_active_subscription(user: user, tier: "basic")

    entry = Marketplace::Catalog.new(user: user, include_eligibility: true).entry_for!(slug: addon_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    expect(presenter.base_entry).to be_nil
    expect(presenter.checkout_base_available?).to be(true)
    expect(presenter.required_base_label).to eq(expert_advisor.name)
    expect(presenter.base_required?).to be(false)
    expect(presenter.selected_addon_keys).to eq([addon_plan.key])
    expect(presenter.addon_rows.map(&:plan_key)).to eq([addon_plan.key])
    expect(presenter.cart_total_cents).to eq(addon_plan.amount_cents)
  end

  it "excludes purchased items from related items but includes matches by type or tags" do
    _current_plan, current_product = create_base_product_for(expert_advisor: expert_advisor, title: "Current")
    expert_advisor.tag_list.add("alpha")
    expert_advisor.save!

    same_type_plan = create(:billing_plan, :one_time)
    same_type_ea = create(:expert_advisor, name: "Same Type")
    create(:billing_plan_entitlement, billing_plan: same_type_plan, expert_advisor: same_type_ea)
    same_type_product = create(:marketplace_product, billing_plan: same_type_plan, title_en: "Same Type Product")

    tagged_plan = create(:billing_plan, :one_time)
    tagged_course = create(:course, title_en: "Tagged Course")
    tagged_course.tag_list.add("alpha")
    tagged_course.save!
    create(:course_plan_entitlement, billing_plan: tagged_plan, course: tagged_course)
    tagged_product = create(:marketplace_product, billing_plan: tagged_plan, title_en: "Tagged Product")

    purchased_plan = create(:billing_plan, :one_time)
    purchased_ea = create(:expert_advisor, name: "Purchased EA")
    purchased_ea.tag_list.add("alpha")
    purchased_ea.save!
    create(:billing_plan_entitlement, billing_plan: purchased_plan, expert_advisor: purchased_ea)
    purchased_product = create(:marketplace_product, billing_plan: purchased_plan, title_en: "Purchased Product")
    create(:marketplace_purchase, user: user, billing_plan: purchased_plan)

    entry = Marketplace::Catalog.new(user: user).entry_for!(slug: current_product.slug)
    presenter = described_class.new(user: user, entry: entry, locale: :en).call

    titles = presenter.related_items.map(&:title)
    expect(titles).to include(same_type_product.title_for(:en))
    expect(titles).to include(tagged_product.title_for(:en))
    expect(titles).not_to include(purchased_product.title_for(:en))
  end
end
