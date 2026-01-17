require "rails_helper"

RSpec.describe "ActiveAdmin access", type: :request do
  it "allows admin users to view the dashboard" do
    admin = create(:user, :admin)
    sign_in admin, scope: :user

    get "/admin"
    follow_redirect! if response.redirect?

    expect(response).to have_http_status(:ok)
  end

  it "redirects non-admin users away from admin" do
    user = create(:user)
    sign_in user, scope: :user

    get "/admin"

    expect(response).to redirect_to(root_path)
  end

  it "prevents admins from viewing master admin users" do
    admin = create(:user, :admin)
    master_admin = create(:user, :master_admin)
    sign_in admin, scope: :user

    get admin_user_path(master_admin)

    expect(response).to have_http_status(:not_found)
  end
end
