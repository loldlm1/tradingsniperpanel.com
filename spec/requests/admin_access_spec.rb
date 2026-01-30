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

  it "updates roles without requiring a password for master admins" do
    master_admin = create(:user, :master_admin)
    user = create(:user, role: :trader)
    sign_in master_admin, scope: :user

    patch admin_user_path(user), params: { user: { role: "partner" } }

    expect(response).to have_http_status(:found)
    expect(user.reload.role).to eq("partner")
  end

  it "blocks admins from updating roles" do
    admin = create(:user, :admin)
    user = create(:user, role: :trader)
    sign_in admin, scope: :user

    patch admin_user_path(user), params: { user: { role: "partner" } }

    expect(response).to redirect_to(edit_admin_user_path(user))
    expect(user.reload.role).to eq("trader")
  end
end
