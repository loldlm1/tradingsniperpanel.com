require "rails_helper"

RSpec.describe "Dashboard settings", type: :request do
  let(:user) { create(:user, name: "Old Name", password: "password123") }

  before do
    sign_in user, scope: :user
  end

  it "renders the settings page" do
    get dashboard_settings_path

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.settings.page_title"))
    expect(response.body).to include(user.email)
  end

  it "updates the name without requiring current password" do
    patch dashboard_settings_path, params: { user: { name: "New Name" } }

    expect(response).to redirect_to(dashboard_settings_path)
    expect(user.reload.name).to eq("New Name")
  end

  it "requires current password when changing the password" do
    patch dashboard_settings_path, params: {
      user: {
        name: "New Name",
        password: "new-password-123",
        password_confirmation: "new-password-123"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?("new-password-123")).to eq(false)
  end

  it "changes the password with the correct current password" do
    patch dashboard_settings_path, params: {
      user: {
        name: "New Name",
        current_password: "password123",
        password: "new-password-123",
        password_confirmation: "new-password-123"
      }
    }

    expect(response).to redirect_to(dashboard_settings_path)
    expect(user.reload.valid_password?("new-password-123")).to eq(true)
  end

  it "redirects Devise edit registration to dashboard settings" do
    get edit_user_registration_path

    expect(response).to redirect_to(dashboard_settings_path)
  end
end

