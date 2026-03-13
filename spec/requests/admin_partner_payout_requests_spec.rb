require "rails_helper"

RSpec.describe "Admin partner payout requests", type: :request do
  it "lets admins mark partner payout requests as paid" do
    admin = create(:user, :admin)
    partner = create(:user)
    profile = create(:partner_profile, user: partner)
    referred_user = create(:user)
    membership = create(:partner_membership, partner_profile: profile, user: referred_user)
    request = create(:partner_payout_request, partner_profile: profile, status: :pending, notification_status: :sent, total_cents: 25_000)
    create(
      :partner_commission,
      partner_profile: profile,
      partner_membership: membership,
      referred_user: referred_user,
      payout_request: request,
      status: :requested,
      amount_cents: 25_000
    )
    sign_in admin, scope: :user

    patch admin_partner_payout_request_path(request), params: {
      partner_payout_request: {
        status: "paid",
        payment_reference: "wire-123",
        note: "Paid manually"
      }
    }

    expect(response).to redirect_to(admin_partner_payout_request_path(request))
    expect(request.reload.status).to eq("paid")
    expect(request.payment_reference).to eq("wire-123")
    expect(request.partner_commissions.first.status).to eq("paid")
  end
end
