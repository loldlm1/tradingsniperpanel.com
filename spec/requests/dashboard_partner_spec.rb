require "rails_helper"

RSpec.describe "Partner dashboard", type: :request do
  let(:partner_user) { create(:user, :partner_enabled) }
  let(:partner_profile) { partner_user.partner_profile }

  before do
    sign_in partner_user, scope: :user
  end

  it "requires an active partner profile" do
    sign_out partner_user
    regular_user = create(:user)
    sign_in regular_user, scope: :user

    get dashboard_partner_path(locale: :en)

    expect(response).to redirect_to(dashboard_path(locale: :en))
  end

  it "renders direct referrals and the partner code" do
    referred_user = create(:user, email: "referred@example.com")
    Referrals::AttachReferrer.new(user: referred_user, code: partner_profile.referral_code).call

    get dashboard_partner_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(partner_profile.referral_code)
    expect(response.body).to include("referred@example.com")
  end

  it "prevents payout requests below the minimum threshold" do
    referred_user = create(:user)
    create(
      :partner_commission,
      partner_profile: partner_profile,
      partner_membership: create(:partner_membership, partner_profile: partner_profile, user: referred_user),
      referred_user: referred_user,
      amount_cents: 19_000
    )

    post request_payout_dashboard_partner_path(locale: :en)

    expect(response).to redirect_to(dashboard_partner_path(locale: :en))
    expect(flash[:alert]).to be_present
    expect(PartnerPayoutRequest.count).to eq(0)
  end

  it "creates a payout request and queues the notification job once" do
    referred_user = create(:user)
    membership = create(:partner_membership, partner_profile: partner_profile, user: referred_user)
    create(:partner_commission, partner_profile: partner_profile, partner_membership: membership, referred_user: referred_user, amount_cents: 21_000)
    allow(Partners::SendPayoutRequestNotificationJob).to receive(:perform_later)

    post request_payout_dashboard_partner_path(locale: :en)

    expect(response).to redirect_to(dashboard_partner_path(locale: :en))
    expect(PartnerPayoutRequest.count).to eq(1)
    expect(Partners::SendPayoutRequestNotificationJob).to have_received(:perform_later).once
  end
end
