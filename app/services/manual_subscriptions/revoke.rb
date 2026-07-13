module ManualSubscriptions
  class Revoke
    class IdempotencyConflict < StandardError; end
    class NotRevocable < StandardError; end
    class Unauthorized < StandardError; end

    def initialize(subscription:, actor:, request_id:, now: Time.current)
      @subscription = subscription
      @actor = actor
      @request_id = request_id.to_s
      @now = now
    end

    def call
      validate_contract!
      event = existing_event
      return subscription_from(event) if event

      subscription.with_lock do
        event = existing_event
        return subscription_from(event) if event

        raise NotRevocable, "manual subscription cannot be revoked" unless subscription.revocable?(now)

        previous_status = subscription.status
        subscription.update!(status: ManualSubscription::STATUSES.fetch(:cancelled))
        AdminAuditEvent.create!(
          actor: actor,
          action: AdminAuditEvent::ACTIONS.fetch(:manual_subscription_revoked),
          target: subscription.user,
          request_id: request_id,
          metadata: {
            "manual_subscription_id" => subscription.id,
            "billing_plan_id" => subscription.billing_plan_id,
            "previous_status" => previous_status,
            "starts_at" => subscription.starts_at.iso8601(6),
            "ends_at" => subscription.ends_at.iso8601(6),
            "revoked_at" => now.iso8601(6)
          }
        )
      end

      subscription
    rescue ActiveRecord::RecordNotUnique
      subscription_from(existing_event!)
    end

    private

    attr_reader :subscription, :actor, :request_id, :now

    def validate_contract!
      raise ArgumentError, "manual subscription is required" unless subscription.is_a?(ManualSubscription) && subscription.persisted?
      raise Unauthorized, "admin access is required" unless authorized_actor?
      raise ArgumentError, "request_id is required" if request_id.blank? || request_id.length > 128
    end

    def authorized_actor?
      actor.is_a?(User) && actor.persisted? && (actor.admin? || actor.master_admin?)
    end

    def existing_event
      event = AdminAuditEvent.find_by(request_id: request_id)
      return unless event
      return event if matching_event?(event)

      raise IdempotencyConflict, "request_id was already used for another admin operation"
    end

    def existing_event!
      existing_event || raise(IdempotencyConflict, "admin operation could not be recovered")
    end

    def matching_event?(event)
      event.actor_id == actor.id &&
        event.action == AdminAuditEvent::ACTIONS.fetch(:manual_subscription_revoked) &&
        event.target_type == "User" &&
        event.target_id == subscription.user_id &&
        Integer(event.metadata["manual_subscription_id"], exception: false) == subscription.id
    end

    def subscription_from(event)
      subscription_id = Integer(event.metadata["manual_subscription_id"], exception: false)
      raise IdempotencyConflict, "manual subscription revocation could not be recovered" unless subscription_id == subscription.id

      ManualSubscription.find(subscription_id)
    end
  end
end
