require "rails_helper"
require "base64"

RSpec.describe SupportRequestsMailer, type: :mailer do
  around do |example|
    original = ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"]
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = "ops@example.com,finance@example.com"
    example.run
  ensure
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = original
  end

  def attach_png(record, filename: "screenshot.png")
    record.screenshots.attach(
      io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7ZxV0AAAAASUVORK5CYII=")),
      filename: filename,
      content_type: "image/png"
    )
  end

  it "renders the internal support request email with screenshot links" do
    support_request = create(:support_request, message: "Need help with my license")
    attach_png(support_request)

    mail = described_class.with(support_request: support_request).request_notification
    blob_url = Rails.application.routes.url_helpers.rails_blob_url(support_request.screenshots.first, host: "example.com", disposition: "attachment")

    expect(mail).to be_multipart
    expect(mail.to).to eq(["ops@example.com", "finance@example.com"])
    expect(mail.subject).to include(I18n.t("support_requests_mailer.request_notification.subject", app_short_name: described_class.email_subject_brand))
    expect(mail.html_part.body.decoded).to include("Need help with my license")
    expect(mail.html_part.body.decoded).to include("screenshot.png")
    expect(mail.html_part.body.decoded).to include(blob_url)
    expect(mail.text_part.body.decoded).to include("Need help with my license")
    expect(mail.text_part.body.decoded).to include(blob_url)
  end

  it "raises when the internal recipient config is missing" do
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = ""
    support_request = create(:support_request)

    expect {
      described_class.with(support_request: support_request).request_notification.deliver_now
    }.to raise_error(ArgumentError, "PARTNER_PAYOUT_REQUEST_RECIPIENTS is not configured")
  end
end
