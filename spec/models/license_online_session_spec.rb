require "rails_helper"

RSpec.describe LicenseOnlineSession, type: :model do
  it "normalizes company to lowercase" do
    session = build(
      :license_online_session,
      company: "  BrokerX  "
    )

    session.validate

    expect(session.company).to eq("brokerx")
  end

  it "dedupes by user, ea, company, account_number, and account_type" do
    user = create(:user)
    expert_advisor = create(:expert_advisor)
    create(
      :license_online_session,
      user: user,
      expert_advisor: expert_advisor,
      company: "BrokerX",
      account_number: 1234,
      account_type: "real"
    )

    duplicate = build(
      :license_online_session,
      user: user,
      expert_advisor: expert_advisor,
      company: "brokerx",
      account_number: 1234,
      account_type: "real"
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:account_number]).to include("has already been taken")
  end

  it "allows same broker identity across different EAs" do
    user = create(:user)
    ea1 = create(:expert_advisor)
    ea2 = create(:expert_advisor)

    create(
      :license_online_session,
      user: user,
      expert_advisor: ea1,
      company: "brokerx",
      account_number: 999,
      account_type: "demo"
    )

    second = build(
      :license_online_session,
      user: user,
      expert_advisor: ea2,
      company: "brokerx",
      account_number: 999,
      account_type: "demo"
    )

    expect(second).to be_valid
  end
end
