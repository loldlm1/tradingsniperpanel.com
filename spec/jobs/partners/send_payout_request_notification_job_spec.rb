require "rails_helper"

RSpec.describe Partners::SendPayoutRequestNotificationJob, type: :job do
  let(:partner) { create(:user) }
  let(:partner_profile) { create(:partner_profile, user: partner) }
  let(:request) { create(:partner_payout_request, partner_profile: partner_profile, notification_status: :queued) }
  let(:mail_delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  it "marks the payout request notification as sent when delivery succeeds" do
    allow(PartnerPayoutRequestsMailer).to receive(:with).with(partner_payout_request: request).and_return(
      instance_double(PartnerPayoutRequestsMailer, request_notification: mail_delivery)
    )

    described_class.perform_now(request.id)

    expect(request.reload.notification_status).to eq("sent")
    expect(request.notification_sent_at).to be_present
  end

  it "marks the payout request notification as failed when delivery raises" do
    allow(PartnerPayoutRequestsMailer).to receive(:with).with(partner_payout_request: request).and_return(
      instance_double(PartnerPayoutRequestsMailer, request_notification: instance_double(ActionMailer::MessageDelivery))
    )
    allow(mail_delivery).to receive(:deliver_now).and_raise(StandardError, "smtp down")
    allow(PartnerPayoutRequestsMailer).to receive(:with).with(partner_payout_request: request).and_return(
      instance_double(PartnerPayoutRequestsMailer, request_notification: mail_delivery)
    )

    described_class.perform_now(request.id)

    expect(request.reload.notification_status).to eq("failed")
    expect(request.notification_failure_message).to include("smtp down")
  end
end
