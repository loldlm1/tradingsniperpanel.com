module Billing
  class ActiveSubscriptionFinder
    Result = Struct.new(:subscription, :customer, :source, keyword_init: true) do
      def stripe?
        source == :stripe && subscription.present?
      end

      def manual?
        source == :manual && subscription.present?
      end
    end

    def initialize(user:)
      @user = user
    end

    def call
      return Result.new unless user

      stripe_result = resolve_stripe_subscription
      manual_subscription = resolve_manual_subscription

      return stripe_result if stripe_result.subscription.present?

      if manual_subscription
        return Result.new(
          subscription: manual_subscription,
          customer: stripe_result.customer,
          source: :manual
        )
      end

      stripe_result.customer.present? ? stripe_result : Result.new
    end

    private

    attr_reader :user

    def resolve_stripe_subscription
      return Result.new unless user.respond_to?(:pay_customers)
      return Result.new unless Pay::Customer.table_exists?
      return Result.new unless Pay::Subscription.table_exists?

      customers = user.pay_customers.order(default: :desc, created_at: :asc)
      customer_ids = customers.select(:id)
      subscription = Pay::Subscription.where(customer_id: customer_ids).active.order(created_at: :desc).first
      customer = subscription&.customer || customers.first

      Result.new(subscription: subscription, customer: customer, source: :stripe)
    end

    def resolve_manual_subscription
      return nil unless ManualSubscription.table_exists?

      ManualSubscription.active_at(Time.current).where(user: user).order(ends_at: :desc).first
    end
  end
end
