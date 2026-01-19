require "rails_helper"

RSpec.describe RevenueSplitPayout, type: :model do
  it "requires paid details when marked as paid" do
    payout = build(:revenue_split_payout, paid_at: nil, paid_by_admin: nil, status: :paid)

    expect(payout).not_to be_valid
    expect(payout.errors[:paid_at]).to be_present
    expect(payout.errors[:paid_by_admin]).to be_present
  end

  it "rejects non-master admins as paid_by_admin" do
    admin = create(:user, :admin)
    payout = build(:revenue_split_payout, paid_by_admin: admin, status: :paid, paid_at: Time.current)

    expect(payout).not_to be_valid
    expect(payout.errors[:paid_by_admin]).to be_present
  end

  it "requires split amounts to match net" do
    payout = build(:revenue_split_payout, net_cents: 1000, us_cents: 400, client_cents: 500)

    expect(payout).not_to be_valid
    expect(payout.errors[:base]).to be_present
  end

  it "allowlists ransack associations and attributes" do
    expect(described_class.ransackable_associations).to match_array(["paid_by_admin"])
    expect(described_class.ransackable_attributes).to match_array(
      %w[created_at ends_at id paid_at paid_by_admin_id period_key starts_at status]
    )
  end
end
