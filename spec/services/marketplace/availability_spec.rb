require "rails_helper"

RSpec.describe Marketplace::Availability do
  it "keeps new marketplace commerce disabled even when legacy records are active" do
    create(:marketplace_product)

    expect(described_class.new.call).to be(false)
  end
end
