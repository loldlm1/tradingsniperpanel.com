module Billing
  class ActiveSubscriptionFinder
    Result = Struct.new(:subscription, :customer, :source, keyword_init: true) do
      def stripe?
        source == :stripe
      end

      def manual?
        source == :manual
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

      customer = user.pay_customers.first
      return Result.new unless customer

      subscription = customer.subscriptions.active.order(created_at: :desc).first
      Result.new(subscription: subscription, customer: customer, source: :stripe)
    end

    def resolve_manual_subscription
      return nil unless ManualSubscription.table_exists?

      ManualSubscription.active.where(user: user).order(ends_at: :desc).first
    end
  end
end
