require "rails_helper"

RSpec.describe SupportRequests::SendNotificationJob, type: :job do
  around do |example|
    original = ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"]
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = "ops@example.com"
    example.run
  ensure
    ENV["PARTNER_PAYOUT_REQUEST_RECIPIENTS"] = original
  end

  it "delivers the support request notification" do
    support_request = create(:support_request)
    mail_delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    mailer = instance_double(SupportRequestsMailer, request_notification: mail_delivery)

    expect(SupportRequestsMailer).to receive(:with).with(support_request: support_request).and_return(mailer)

    described_class.perform_now(support_request.id)
  end

  it "returns cleanly when the support request is gone" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  it "re-raises delivery failures so the queue can retry" do
    support_request = create(:support_request)
    mail_delivery = instance_double(ActionMailer::MessageDelivery)
    mailer = instance_double(SupportRequestsMailer, request_notification: mail_delivery)

    allow(SupportRequestsMailer).to receive(:with).with(support_request: support_request).and_return(mailer)
    allow(mail_delivery).to receive(:deliver_now).and_raise(Net::ReadTimeout)

    expect { described_class.perform_now(support_request.id) }.to raise_error(Net::ReadTimeout)
  end
end
