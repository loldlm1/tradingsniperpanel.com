require "rails_helper"

RSpec.describe Partners::PayoutRequestor, type: :service do
  let(:partner) { create(:user) }
  let(:partner_profile) { create(:partner_profile, user: partner) }
  let(:referred_user) { create(:user) }
  let(:partner_membership) { create(:partner_membership, partner_profile: partner_profile, user: referred_user) }

  before do
    allow(Partners::SendPayoutRequestNotificationJob).to receive(:perform_later)
  end

  it "creates a payout request and queues a single notification job when threshold is met" do
    create(:partner_commission, partner_profile: partner_profile, partner_membership: partner_membership, referred_user: referred_user, amount_cents: 12_000)
    create(:partner_commission, partner_profile: partner_profile, partner_membership: partner_membership, referred_user: referred_user, amount_cents: 10_500)

    result = described_class.new(partner_profile: partner_profile).call

    expect(result.status).to eq(:created)
    expect(PartnerPayoutRequest.count).to eq(1)

    request = PartnerPayoutRequest.last
    expect(request.total_cents).to eq(22_500)
    expect(request.notification_status).to eq("queued")
    expect(partner_profile.partner_commissions.requested.count).to eq(2)
    expect(Partners::SendPayoutRequestNotificationJob).to have_received(:perform_later).with(request.id).once
  end

  it "blocks payout creation below the minimum threshold" do
    create(:partner_commission, partner_profile: partner_profile, partner_membership: partner_membership, referred_user: referred_user, amount_cents: 19_999)

    result = described_class.new(partner_profile: partner_profile).call

    expect(result.status).to eq(:below_minimum)
    expect(PartnerPayoutRequest.count).to eq(0)
    expect(Partners::SendPayoutRequestNotificationJob).not_to have_received(:perform_later)
  end

  it "retries the same pending request when notification previously failed" do
    request = create(:partner_payout_request, partner_profile: partner_profile, notification_status: :failed, total_cents: 25_000)

    result = described_class.new(partner_profile: partner_profile).call

    expect(result.status).to eq(:retried)
    expect(PartnerPayoutRequest.count).to eq(1)
    expect(request.reload.notification_status).to eq("queued")
    expect(Partners::SendPayoutRequestNotificationJob).to have_received(:perform_later).with(request.id).once
  end
end
