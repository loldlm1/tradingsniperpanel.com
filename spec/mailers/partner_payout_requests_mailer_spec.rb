require "rails_helper"

RSpec.describe PartnerPayoutRequestsMailer, type: :mailer do
  around do |example|
    original = ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"]
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = "ops@example.com,finance@example.com"
    example.run
  ensure
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = original
  end

  it "renders the internal payout request email" do
    partner = create(:user, name: "Partner Jane", email: "partner@example.com")
    profile = create(:partner_profile, user: partner, referral_code: "PARTNER55")
    request = create(:partner_payout_request, partner_profile: profile, total_cents: 25_000, notification_status: :queued)

    mail = described_class.with(partner_payout_request: request).request_notification

    expect(mail).to be_multipart
    expect(mail.to).to eq(["ops@example.com", "finance@example.com"])
    expect(mail.subject).to include(I18n.t("partner_payout_requests_mailer.request_notification.subject", app_short_name: described_class.email_subject_brand))
    expect(mail.html_part.body.encoded).to include("Partner Jane")
    expect(mail.html_part.body.encoded).to include("PARTNER55")
    expect(mail.html_part.body.encoded).to include("partner@example.com")
    expect(mail.text_part.body.encoded).to include("Partner Jane")
    expect(mail.text_part.body.encoded).to include("PARTNER55")
    expect(mail.text_part.body.encoded).to include("partner@example.com")
  end
end
