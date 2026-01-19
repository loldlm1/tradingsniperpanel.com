require "rails_helper"

RSpec.describe Admin::Analytics::PeriodResolver do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    Time.use_zone("UTC") { example.run }
  end

  it "returns the first half of the month" do
    period = described_class.new(key: "first_half", as_of: Time.zone.parse("2026-01-10")).call

    expect(period.starts_at).to eq(Time.zone.parse("2026-01-01").beginning_of_day)
    expect(period.ends_at).to eq(Time.zone.parse("2026-01-15").end_of_day)
  end

  it "returns the second half of the month" do
    period = described_class.new(key: "second_half", as_of: Time.zone.parse("2026-01-20")).call

    expect(period.starts_at).to eq(Time.zone.parse("2026-01-16").beginning_of_day)
    expect(period.ends_at).to eq(Time.zone.parse("2026-01-31").end_of_day)
  end

  it "returns the full month for monthly" do
    period = described_class.new(key: "monthly", as_of: Time.zone.parse("2026-01-20")).call

    expect(period.starts_at).to eq(Time.zone.parse("2026-01-01").beginning_of_day)
    expect(period.ends_at).to eq(Time.zone.parse("2026-01-31").end_of_day)
  end
end
