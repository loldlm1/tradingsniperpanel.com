require "rails_helper"

RSpec.describe "Revenue split payouts admin", type: :request do
  around do |example|
    Time.use_zone("UTC") { example.run }
  end

  it "allows admins to create payouts" do
    admin = create(:user, :admin)
    sign_in admin, scope: :user

    create(:revenue_split_rule, effective_at: Time.zone.parse("2026-01-01"), us_percent: 40, client_percent: 60)
    create(
      :manual_transaction,
      amount_cents: 10_000,
      paid_at: Time.zone.parse("2026-01-10"),
      recorded_by_admin: admin
    )

    post admin_revenue_split_payouts_path, params: {
      revenue_split_payout: { period_key: "first_half", as_of: "2026-01-10" }
    }

    expect(response).to redirect_to(admin_revenue_split_payout_path(RevenueSplitPayout.last))
    expect(RevenueSplitPayout.count).to eq(1)
  end

  it "allows master admins to create payouts" do
    master_admin = create(:user, :master_admin)
    sign_in master_admin, scope: :user

    create(:revenue_split_rule, effective_at: Time.zone.parse("2026-01-01"), us_percent: 40, client_percent: 60)
    create(
      :manual_transaction,
      amount_cents: 10_000,
      paid_at: Time.zone.parse("2026-01-10"),
      recorded_by_admin: master_admin
    )

    post admin_revenue_split_payouts_path, params: {
      revenue_split_payout: { period_key: "first_half", as_of: "2026-01-10" }
    }

    expect(response).to redirect_to(admin_revenue_split_payout_path(RevenueSplitPayout.last))
    expect(RevenueSplitPayout.count).to eq(1)
    expect(RevenueSplitPayout.last).to be_paid
  end
end
