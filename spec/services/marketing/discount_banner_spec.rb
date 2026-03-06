require "rails_helper"

RSpec.describe Marketing::DiscountBanner do
  around do |example|
    original_code = ENV["DISCOUNT_BANNER_CODE"]
    original_percent = ENV["DISCOUNT_BANNER_PERCENT"]

    example.run
  ensure
    ENV["DISCOUNT_BANNER_CODE"] = original_code
    ENV["DISCOUNT_BANNER_PERCENT"] = original_percent
  end

  it "returns banner payload when code and percent are valid" do
    ENV["DISCOUNT_BANNER_CODE"] = "1234"
    ENV["DISCOUNT_BANNER_PERCENT"] = "15%"

    expect(described_class.new.call).to eq(
      code: "1234",
      percent: 15
    )
  end

  it "accepts percent values without a percent sign" do
    ENV["DISCOUNT_BANNER_CODE"] = "VIP"
    ENV["DISCOUNT_BANNER_PERCENT"] = "20"

    expect(described_class.new.call).to eq(
      code: "VIP",
      percent: 20
    )
  end

  it "returns nil when the percent value is invalid" do
    ENV["DISCOUNT_BANNER_CODE"] = "VIP"
    ENV["DISCOUNT_BANNER_PERCENT"] = "abc"

    expect(described_class.new.call).to be_nil
  end
end
