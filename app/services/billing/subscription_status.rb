module Billing
  class SubscriptionStatus
    def initialize(subscription)
      @subscription = subscription
    end

    def paid_active?
      return false unless subscription
      return false if trialing?
      return false if failed?

      active_until = subscription.current_period_end || subscription.ends_at
      return true if active_until.nil?

      active_until.future?
    end

    def trialing?
      return false unless subscription
      return true if subscription.status.to_s == "trialing"

      trial_ends_at = subscription.respond_to?(:trial_ends_at) ? subscription.trial_ends_at : nil
      trial_ends_at.present? && trial_ends_at.future?
    end

    def failed?
      return false unless subscription

      subscription.past_due? || subscription.unpaid? || subscription.status == "incomplete_expired"
    end

    private

    attr_reader :subscription
  end
end
