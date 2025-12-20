require "rails_helper"

RSpec.describe BrokerAccount, type: :model do
  it "validates uniqueness of company/account_number/account_type" do
    license = create(:license)
    create(:broker_account, license:, company: "BrokerX", account_number: 1234, account_type: :real)

    duplicate = build(:broker_account, license:, company: "BrokerX", account_number: 1234, account_type: :real)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:account_number]).to include("has already been taken")
  end

  it "requires account_number to be integer" do
    account = build(:broker_account, account_number: "abc")

    expect(account).not_to be_valid
    expect(account.errors[:account_number]).to be_present
  end
end
