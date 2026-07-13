FactoryBot.define do
  factory :admin_audit_event do
    association :actor, factory: [ :user, :admin ]
    action { AdminAuditEvent::ACTIONS.fetch(:manual_subscription_granted) }
    association :target, factory: :user
    metadata { { "manual_subscription_id" => 1 } }
    request_id { SecureRandom.uuid }
  end
end
