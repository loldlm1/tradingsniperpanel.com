require "rails_helper"

RSpec.describe "Partner dashboard", type: :request do
  let(:partner_user) { create(:user, :partner_enabled) }
  let(:partner_profile) { partner_user.partner_profile }

  before do
    sign_in partner_user, scope: :user
  end

  it "requires an active partner profile" do
    sign_out :user
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

  it "renders payout history and removes the commission log section" do
    request = create(
      :partner_payout_request,
      partner_profile: partner_profile,
      status: :paid,
      notification_status: :sent,
      total_cents: 48_500,
      payment_reference: "wire-2026-001",
      paid_at: Time.current
    )

    get dashboard_partner_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("partner_dashboard.payout_history"))
    expect(response.body).to include("wire-2026-001")
    expect(response.body).not_to include(I18n.t("partner_dashboard.revenue", default: "Commission log"))
  end

  it "filters direct referrals by email" do
    matching_user = create(:user, email: "partner-filter@example.com")
    other_user = create(:user, email: "outside-filter@example.com")
    Referrals::AttachReferrer.new(user: matching_user, code: partner_profile.referral_code).call
    Referrals::AttachReferrer.new(user: other_user, code: partner_profile.referral_code).call

    get dashboard_partner_path(locale: :en, q: "partner-filter")

    expect(response).to be_successful
    expect(response.body).to include("partner-filter@example.com")
    expect(response.body).not_to include("outside-filter@example.com")
    expect(response.body).to include(I18n.t("partner_dashboard.clear_search"))
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
