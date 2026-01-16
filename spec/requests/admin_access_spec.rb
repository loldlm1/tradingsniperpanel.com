require "rails_helper"

RSpec.describe "ActiveAdmin access", type: :request do
  it "allows admin users to view the dashboard" do
    admin = create(:user, :admin)
    sign_in admin

    get "/admin"
    follow_redirect! if response.redirect?

    expect(response).to have_http_status(:ok)
  end

  it "redirects non-admin users away from admin" do
    user = create(:user)
    sign_in user

    get "/admin"

    expect(response).to redirect_to(root_path)
  end
end
