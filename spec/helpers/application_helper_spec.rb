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

  it "exposes branding values from configuration" do
    original_name = Rails.configuration.x.branding.app_name
    original_short_name = Rails.configuration.x.branding.short_name
    original_support_email = Rails.configuration.x.branding.support_email

    Rails.configuration.x.branding.app_name = "Spec App Name"
    Rails.configuration.x.branding.short_name = "Spec Short"
    Rails.configuration.x.branding.support_email = "spec@example.com"

    expect(helper.app_name).to eq("Spec App Name")
    expect(helper.app_short_name).to eq("Spec Short")
    expect(helper.support_email).to eq("spec@example.com")
  ensure
    Rails.configuration.x.branding.app_name = original_name
    Rails.configuration.x.branding.short_name = original_short_name
    Rails.configuration.x.branding.support_email = original_support_email
  end
end
