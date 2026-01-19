require "rails_helper"

RSpec.describe "Seeds::AdminBootstrap" do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    original_env = ENV.to_hash
    example.run
  ensure
    ENV.replace(original_env)
  end

  before do
    load Rails.root.join("db", "seeds", "bootstrap.rb")
  end

  def set_env(values)
    values.each { |key, value| ENV[key] = value }
  end

  it "creates a master admin and revenue split rule from env" do
    travel_to Time.utc(2025, 1, 15, 12, 30, 0) do
      set_env(
        "MASTER_ADMIN_EMAIL" => "master@example.com",
        "MASTER_ADMIN_PASSWORD" => "password123",
        "REVENUE_SPLIT_US_PERCENT" => "40",
        "REVENUE_SPLIT_CLIENT_PERCENT" => "60"
      )

      expect do
        Seeds::AdminBootstrap.seed!
      end.to change(User, :count).by(1)
        .and change(RevenueSplitRule, :count).by(1)

      user = User.find_by(email: "master@example.com")
      expect(user).to be_master_admin

      rule = RevenueSplitRule.first
      expect(rule.us_percent).to eq(40)
      expect(rule.client_percent).to eq(60)
      expect(rule.effective_at).to eq(Time.utc(2025, 1, 15))
    end
  end

  it "does not reset the master admin password on re-run" do
    set_env(
      "MASTER_ADMIN_EMAIL" => "master@example.com",
      "MASTER_ADMIN_PASSWORD" => "password123",
      "REVENUE_SPLIT_US_PERCENT" => "40",
      "REVENUE_SPLIT_CLIENT_PERCENT" => "60"
    )

    Seeds::AdminBootstrap.seed!
    user = User.find_by(email: "master@example.com")
    original_password = user.encrypted_password

    ENV["MASTER_ADMIN_PASSWORD"] = "newpassword456"
    Seeds::AdminBootstrap.seed!

    expect(user.reload.encrypted_password).to eq(original_password)
  end

  it "keeps a single revenue split rule" do
    set_env(
      "MASTER_ADMIN_EMAIL" => "master@example.com",
      "MASTER_ADMIN_PASSWORD" => "password123",
      "REVENUE_SPLIT_US_PERCENT" => "40",
      "REVENUE_SPLIT_CLIENT_PERCENT" => "60"
    )

    create(:revenue_split_rule, us_percent: 50, client_percent: 50, effective_at: 2.days.ago)

    Seeds::AdminBootstrap.seed!
    expect(RevenueSplitRule.count).to eq(1)

    rule = RevenueSplitRule.first
    expect(rule.us_percent).to eq(40)
    expect(rule.client_percent).to eq(60)
  end
end
