require "rails_helper"

RSpec.describe "layouts/application", type: :view do
  around do |example|
    original = I18n.locale
    I18n.locale = :es
    example.run
    I18n.locale = original
  end

  before do
    allow(view).to receive(:user_signed_in?).and_return(false)
    allow(view).to receive(:current_user).and_return(nil)
  end

  it "renders the lang attribute and locale switcher links" do
    render template: "pages/home", layout: "layouts/application"

    expect(rendered).to include(%(lang="es"))
    expect(rendered).to include(I18n.t("nav.pricing"))
    expect(rendered).to include("EN")
    expect(rendered).to include("ES")
  end
end
