require "rails_helper"

RSpec.describe "QA partner seeds" do
  before do
    load Rails.root.join("db", "seeds", "shared.rb") unless defined?(Seeds::QaUsers)
  end

  it "creates partner memberships and commissions idempotently" do
    skip "Refer is not available" unless defined?(Refer)

    qa_users = Seeds::QaUsers.seed!
    partner = qa_users[:partner]
    expect(partner).to be_present

    Seeds::Partners.seed_qa!(partner: partner)
    profile = partner.partner_profile
    expect(profile).to be_present

    referred_emails = Seeds::Partners::DEFAULT_REFERRED_EMAILS
    referred_users = User.where(email: referred_emails)
    expect(referred_users.count).to eq(referred_emails.size)

    memberships = PartnerMembership.active.where(user: referred_users, partner_profile: profile)
    expect(memberships.count).to eq(referred_emails.size)

    commissions = PartnerCommission.where(partner_profile: profile)
    expect(commissions.pending).to exist
    expect(commissions.requested).to exist
    expect(commissions.paid).to exist

    expect(PartnerPayoutRequest.where(partner_profile: profile).pending).to exist
    expect(PartnerPayoutRequest.where(partner_profile: profile).paid).to exist

    subscribed_user = User.find_by(email: referred_emails.first)
    subscription = subscribed_user&.pay_customers&.first&.subscriptions&.active&.first
    expect(subscription).to be_present

    counts = {
      memberships: memberships.count,
      commissions: commissions.count,
      requests: PartnerPayoutRequest.where(partner_profile: profile).count
    }

    Seeds::Partners.seed_qa!(partner: partner)

    expect(PartnerMembership.active.where(user: referred_users, partner_profile: profile).count).to eq(counts[:memberships])
    expect(PartnerCommission.where(partner_profile: profile).count).to eq(counts[:commissions])
    expect(PartnerPayoutRequest.where(partner_profile: profile).count).to eq(counts[:requests])
  end
end
