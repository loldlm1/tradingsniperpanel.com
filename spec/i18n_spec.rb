require "rails_helper"

RSpec.describe "I18n translations" do
  it "supports the configured locales" do
    expect(I18n.available_locales.map(&:to_sym)).to include(:en, :es)
  end

  it "provides core copy for both locales" do
    %i[en es].each do |locale|
      expect { I18n.t!("app.name", locale:) }.not_to raise_error
      expect { I18n.t!("hero.title", locale:) }.not_to raise_error
    end
  end
end
