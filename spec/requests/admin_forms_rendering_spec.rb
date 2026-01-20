require "rails_helper"

RSpec.describe "Admin form rendering", type: :request do
  let(:master_admin) { create(:user, :master_admin) }

  before do
    sign_in master_admin, scope: :user
  end

  def expect_form_ok
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("#<Class:")
  end

  it "renders marketplace product forms with relationship inputs" do
    get new_admin_marketplace_product_path
    expect_form_ok
    expect(response.body).to include('name="marketplace_product[plan_amount_cents]"')
    expect(response.body).to include('name="marketplace_product[plan_currency]"')
    expect(response.body).to include('name="marketplace_product[expert_advisor_ids][]"')
    expect(response.body).to include('name="marketplace_product[course_ids][]"')
    expect(response.body).to include('name="marketplace_product[marketplace_asset_ids][]"')
    expect(response.body).to include('name="marketplace_product[addonable_ref]"')
    expect(response.body).to include('name="marketplace_product[addon_key]"')

    product = create(:marketplace_product)
    get edit_admin_marketplace_product_path(product)
    expect_form_ok
  end

  it "renders expert advisor forms with marketplace product linking" do
    get new_admin_expert_advisor_path
    expect_form_ok
    expect(response.body).to include('name="expert_advisor[marketplace_product_ids][]"')

    expert_advisor = create(:expert_advisor)
    get edit_admin_expert_advisor_path(expert_advisor)
    expect_form_ok
  end

  it "renders course forms with marketplace product linking" do
    get new_admin_course_path
    expect_form_ok
    expect(response.body).to include('name="course[marketplace_product_ids][]"')

    course = create(:course)
    get edit_admin_course_path(course)
    expect_form_ok
  end

  it "renders marketplace asset forms with marketplace product linking" do
    get new_admin_marketplace_asset_path
    expect_form_ok
    expect(response.body).to include('name="marketplace_asset[marketplace_product_ids][]"')

    asset = create(:marketplace_asset)
    get edit_admin_marketplace_asset_path(asset)
    expect_form_ok
  end

  it "renders expert advisor bundle forms" do
    get new_admin_expert_advisor_bundle_path
    expect_form_ok

    bundle = create(:expert_advisor_bundle)
    get edit_admin_expert_advisor_bundle_path(bundle)
    expect_form_ok
  end

  it "renders manual transaction forms" do
    get new_admin_manual_transaction_path
    expect_form_ok

    transaction = create(:manual_transaction)
    get edit_admin_manual_transaction_path(transaction)
    expect_form_ok
  end

  it "renders manual subscription forms" do
    get new_admin_manual_subscription_path
    expect_form_ok

    subscription = create(:manual_subscription)
    get edit_admin_manual_subscription_path(subscription)
    expect_form_ok
  end

  it "renders revenue split rule forms" do
    get new_admin_revenue_split_rule_path
    expect_form_ok

    rule = create(:revenue_split_rule)
    get edit_admin_revenue_split_rule_path(rule)
    expect_form_ok
  end

  it "renders revenue split payout forms" do
    get new_admin_revenue_split_payout_path
    expect_form_ok

    payout = create(:revenue_split_payout)
    get edit_admin_revenue_split_payout_path(payout)
    expect_form_ok
  end

  it "renders user forms" do
    get new_admin_user_path
    expect_form_ok

    user = create(:user, :admin)
    get edit_admin_user_path(user)
    expect_form_ok
  end
end
