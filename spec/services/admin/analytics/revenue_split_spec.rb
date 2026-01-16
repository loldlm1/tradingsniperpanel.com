require "rails_helper"

RSpec.describe Admin::Analytics::RevenueSplit, type: :service do
  it "uses the active split rule when present" do
    rule = create(:revenue_split_rule, us_percent: 40, client_percent: 60, effective_at: 1.day.ago)
    result = described_class.new(net_cents: 1000, as_of: Time.current).call

    expect(result.rule).to eq(rule)
    expect(result.us_cents).to eq(400)
    expect(result.client_cents).to eq(600)
    expect(result.missing_rule).to be(false)
  end

  it "falls back to 100/0 split when no rule exists" do
    result = described_class.new(net_cents: 1000, as_of: Time.current).call

    expect(result.us_cents).to eq(1000)
    expect(result.client_cents).to eq(0)
    expect(result.missing_rule).to be(true)
  end
end
