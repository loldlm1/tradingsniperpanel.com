require "rails_helper"

RSpec.describe "pages/home", type: :view do
  around do |example|
    original = I18n.locale
    I18n.locale = :es
    example.run
    I18n.locale = original
  end

  let(:user) { build_stubbed(:user, preferred_locale: "es") }

  context "when guest" do
    before do
      allow(view).to receive(:user_signed_in?).and_return(false)
      allow(view).to receive(:current_user).and_return(nil)
      allow(view).to receive(:default_url_options).and_return({ locale: I18n.locale })
      allow(controller).to receive(:default_url_options).and_return({ locale: I18n.locale })
    end

    it "renders translated hero copy and sign up links" do
      render

      expect(rendered).to include(I18n.t("hero.title"))
      expect(rendered).to include(I18n.t("landing.neon.testimonials.title"))
      first_testimonial = Array(I18n.t("landing.neon.testimonials.items", default: [])).first&.with_indifferent_access
      expect(rendered).to include(first_testimonial[:quote]) if first_testimonial.present?
      expect(rendered).to include(new_user_registration_path(locale: I18n.locale))
      expect(rendered).to include(I18n.t("hero.primary_cta"))
    end
  end

  context "when signed in" do
    before do
      allow(view).to receive(:user_signed_in?).and_return(true)
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:default_url_options).and_return({ locale: I18n.locale })
      allow(controller).to receive(:default_url_options).and_return({ locale: I18n.locale })
    end

    it "points CTAs to the dashboard" do
      render

      expect(rendered).to include(dashboard_path(locale: I18n.locale))
      expect(rendered).to include(I18n.t("hero.primary_cta"))
    end
  end
end
