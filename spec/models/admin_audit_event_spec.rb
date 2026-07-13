require "rails_helper"

RSpec.describe AdminAuditEvent do
  it "accepts safe normalized operation metadata" do
    event = build(:admin_audit_event, metadata: { "affected_license_ids" => [ 1, 2 ], "scope" => "user" })

    expect(event).to be_valid
  end

  it "rejects token and raw processor payload fields at any nesting level" do
    event = build(:admin_audit_event, metadata: { "operation" => { "encrypted_key" => "secret" } })

    expect(event).not_to be_valid
    expect(event.errors[:metadata]).to be_present
  end

  it "requires a unique request identifier" do
    existing = create(:admin_audit_event)
    duplicate = build(:admin_audit_event, request_id: existing.request_id)

    expect(duplicate).not_to be_valid
  end

  it "requires user targets for user operations and no target for global rotation" do
    user_operation = build(:admin_audit_event, target: nil)
    global_operation = build(
      :admin_audit_event,
      action: described_class::ACTIONS.fetch(:all_licenses_rotated),
      target: create(:user)
    )

    expect(user_operation).not_to be_valid
    expect(global_operation).not_to be_valid
  end

  it "accepts manual subscription revocation events targeted at users" do
    event = build(
      :admin_audit_event,
      action: described_class::ACTIONS.fetch(:manual_subscription_revoked),
      metadata: { "manual_subscription_id" => 123, "revoked_at" => Time.current.iso8601(6) }
    )

    expect(event).to be_valid
  end
end
