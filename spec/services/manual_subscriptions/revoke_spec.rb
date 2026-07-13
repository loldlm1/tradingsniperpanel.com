require "rails_helper"
require "securerandom"

RSpec.describe ManualSubscriptions::Revoke do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:admin) { create(:user, :admin) }
  let(:subscription) { create(:manual_subscription) }
  let(:request_id) { SecureRandom.uuid }

  before { clear_enqueued_jobs }
  after { clear_enqueued_jobs }

  it "revokes access atomically while preserving the original period" do
    starts_at = subscription.starts_at
    ends_at = subscription.ends_at

    travel_to Time.current.change(usec: 0) do
      expect do
        described_class.new(
          subscription: subscription,
          actor: admin,
          request_id: request_id
        ).call
      end.to have_enqueued_job(ManualSubscriptions::SyncJob).with(subscription.id)

      expect(subscription.reload).to be_cancelled
      expect(subscription.starts_at).to eq(starts_at)
      expect(subscription.ends_at).to eq(ends_at)

      event = AdminAuditEvent.find_by!(request_id: request_id)
      expect(event.action).to eq(AdminAuditEvent::ACTIONS.fetch(:manual_subscription_revoked))
      expect(event.actor).to eq(admin)
      expect(event.target).to eq(subscription.user)
      expect(event.metadata).to include(
        "manual_subscription_id" => subscription.id,
        "billing_plan_id" => subscription.billing_plan_id,
        "previous_status" => "active",
        "starts_at" => starts_at.iso8601(6),
        "ends_at" => ends_at.iso8601(6),
        "revoked_at" => Time.current.iso8601(6)
      )
    end
  end

  it "treats a repeated request as idempotent" do
    operation = described_class.new(subscription: subscription, actor: admin, request_id: request_id)

    first = operation.call
    second = operation.call

    expect(second).to eq(first)
    expect(AdminAuditEvent.where(request_id: request_id).count).to eq(1)
  end

  it "rejects reuse of the request identifier for another subscription" do
    described_class.new(subscription: subscription, actor: admin, request_id: request_id).call
    other_subscription = create(:manual_subscription)

    expect do
      described_class.new(
        subscription: other_subscription,
        actor: admin,
        request_id: request_id
      ).call
    end.to raise_error(described_class::IdempotencyConflict)
  end

  it "rejects expired or already revoked subscriptions" do
    expired = create(:manual_subscription, status: "expired", starts_at: 31.days.ago, ends_at: 1.day.ago)

    expect do
      described_class.new(subscription: expired, actor: admin, request_id: request_id).call
    end.to raise_error(described_class::NotRevocable)

    described_class.new(subscription: subscription, actor: admin, request_id: SecureRandom.uuid).call

    expect do
      described_class.new(subscription: subscription, actor: admin, request_id: SecureRandom.uuid).call
    end.to raise_error(described_class::NotRevocable)
  end

  it "rejects non-admin actors" do
    expect do
      described_class.new(
        subscription: subscription,
        actor: create(:user),
        request_id: request_id
      ).call
    end.to raise_error(described_class::Unauthorized)
  end

  it "rolls back the revocation when audit creation fails" do
    invalid_event = AdminAuditEvent.new
    allow(AdminAuditEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(invalid_event))

    expect do
      described_class.new(subscription: subscription, actor: admin, request_id: request_id).call
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(subscription.reload).to be_active
  end
end
