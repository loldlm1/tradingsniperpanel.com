require "rails_helper"

RSpec.describe "time formats" do
  it "formats short_with_year for en" do
    time = Time.utc(2025, 1, 2, 12, 0, 0)
    expect(I18n.l(time, locale: :en, format: :short_with_year)).to eq("Jan 2, 2025")
  end

  it "formats short_with_year for es" do
    time = Time.utc(2025, 1, 2, 12, 0, 0)
    expect(I18n.l(time, locale: :es, format: :short_with_year)).to eq(time.strftime("%-d %b %Y"))
  end
end
