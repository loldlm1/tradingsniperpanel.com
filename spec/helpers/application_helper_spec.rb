require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  around do |example|
    original = I18n.locale
    example.run
    I18n.locale = original
  end

  it "returns active classes for the current locale" do
    I18n.locale = :en

    expect(helper.locale_link_class(:en)).to include("bg-blue-500")
    expect(helper.locale_link_class(:en)).to include("text-white")
  end

  it "returns inactive classes for other locales" do
    I18n.locale = :en

    expect(helper.locale_link_class(:es)).to include("text-gray-300")
    expect(helper.locale_link_class(:es)).to include("bg-gray-800/60")
  end
end
