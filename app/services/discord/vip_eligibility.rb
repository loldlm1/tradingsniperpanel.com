module Discord
  class VipEligibility
    Result = Data.define(:eligible, :source, :plan_key, :reason) do
      def eligible?
        eligible
      end
    end

    def initialize(
      user:,
      finder: Billing::ActiveSubscriptionFinder.new(user: user),
      plan_resolver: Billing::SubscriptionPlanResolver,
      status_resolver: Billing::SubscriptionStatus,
      now: Time.current
    )
      @finder = finder
      @plan_resolver = plan_resolver
      @status_resolver = status_resolver
      @now = now
    end

    def call
      access = finder.call
      subscription = access.subscription
      return result(false, source: nil, reason: :no_subscription) unless subscription

      plan = plan_resolver.new(subscription: subscription).plan
      source = access.source&.to_sym
      return result(false, source: source, plan: plan, reason: :wrong_tier) unless pandora_plan?(plan)

      source == :manual ? manual_result(subscription, plan) : stripe_result(subscription, plan)
    end

    private

    attr_reader :finder, :plan_resolver, :status_resolver, :now

    def pandora_plan?(plan)
      plan&.subscription? &&
        plan.tier == Billing::PandoraPricing::TIER &&
        plan.key.in?(Billing::PandoraPricing::PLAN_KEYS)
    end

    def manual_result(subscription, plan)
      if subscription.superseded?
        return result(false, source: :manual, plan: plan, reason: :manual_superseded)
      end
      unless subscription.active_for_time?(now)
        return result(false, source: :manual, plan: plan, reason: :manual_inactive)
      end

      result(true, source: :manual, plan: plan, reason: :eligible_manual)
    end

    def stripe_result(subscription, plan)
      status = status_resolver.new(subscription)
      return result(false, source: :stripe, plan: plan, reason: :trialing) if status.trialing?
      return result(false, source: :stripe, plan: plan, reason: failed_reason(subscription)) if status.failed?
      return result(false, source: :stripe, plan: plan, reason: :inactive) unless status.paid_active?

      result(true, source: :stripe, plan: plan, reason: :eligible_stripe)
    end

    def failed_reason(subscription)
      return :past_due if subscription.past_due?
      return :unpaid if subscription.unpaid?
      return :incomplete_expired if subscription.status.to_s == "incomplete_expired"

      :inactive
    end

    def result(eligible, source:, reason:, plan: nil)
      Result.new(
        eligible: eligible,
        source: source,
        plan_key: plan&.key,
        reason: reason.to_s
      )
    end
  end
end
