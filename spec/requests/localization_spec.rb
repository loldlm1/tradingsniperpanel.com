require "rails_helper"

RSpec.describe "Localization", type: :request do
  around do |example|
    default = I18n.locale
    example.run
    I18n.locale = default
  end

  describe "root page" do
    it "loads successfully for guests and sets session locale" do
      get root_path

      expect(response).to be_successful
      expect(I18n.locale.to_s).to eq(I18n.default_locale.to_s)
      expect(session[:locale]).to eq(I18n.default_locale)
    end

    it "applies locale param and stores it in session" do
      get root_path(locale: :es)

      expect(response).to be_successful
      expect(I18n.locale).to eq(:es)
      expect(session[:locale]).to eq(:es)
    end

    it "falls back to default when locale param is invalid" do
      get root_path, params: { locale: :fr }

      expect(response).to be_successful
      expect(I18n.locale).to eq(I18n.default_locale)
      expect(session[:locale]).to eq(I18n.default_locale)
    end
  end

  describe "persistence for authenticated users" do
    it "persists locale when it changed" do
      user = create(:user, preferred_locale: "en")
      sign_in(user)

      get root_path(locale: :es)

      expect(response).to be_successful
      expect(user.reload.preferred_locale).to eq("es")
    end

    it "does not persist when locale matches current preference" do
      user = create(:user, preferred_locale: "en")
      sign_in(user)

      expect do
        get root_path
      end.not_to(change { user.reload.preferred_locale })
    end
  end

  describe "headers and defaults" do
    it "uses Accept-Language when no param, session, or user locale present" do
      get root_path, headers: { "HTTP_ACCEPT_LANGUAGE" => "es-ES,es;q=0.9,en;q=0.8" }

      expect(I18n.locale).to eq(:es)
      expect(session[:locale]).to eq(:es)
    end
  end
end
