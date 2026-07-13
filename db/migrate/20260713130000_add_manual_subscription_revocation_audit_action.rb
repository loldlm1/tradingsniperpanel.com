class AddManualSubscriptionRevocationAuditAction < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :admin_audit_events, name: "admin_audit_events_target_action_check"
    remove_check_constraint :admin_audit_events, name: "admin_audit_events_action_check"

    add_check_constraint :admin_audit_events,
                         "action IN ('manual_subscription.granted', 'manual_subscription.revoked', " \
                         "'licenses.subscription_rotated', 'licenses.all_rotated')",
                         name: "admin_audit_events_action_check"
    add_check_constraint :admin_audit_events,
                         "(action = 'licenses.all_rotated' AND target_type IS NULL AND target_id IS NULL) OR " \
                         "(action IN ('manual_subscription.granted', 'manual_subscription.revoked', " \
                         "'licenses.subscription_rotated') AND target_type = 'User' AND target_id IS NOT NULL)",
                         name: "admin_audit_events_target_action_check"
  end

  def down
    remove_check_constraint :admin_audit_events, name: "admin_audit_events_target_action_check"
    remove_check_constraint :admin_audit_events, name: "admin_audit_events_action_check"

    add_check_constraint :admin_audit_events,
                         "action IN ('manual_subscription.granted', " \
                         "'licenses.subscription_rotated', 'licenses.all_rotated')",
                         name: "admin_audit_events_action_check"
    add_check_constraint :admin_audit_events,
                         "(action = 'licenses.all_rotated' AND target_type IS NULL AND target_id IS NULL) OR " \
                         "(action IN ('manual_subscription.granted', 'licenses.subscription_rotated') AND " \
                         "target_type = 'User' AND target_id IS NOT NULL)",
                         name: "admin_audit_events_target_action_check"
  end
end
