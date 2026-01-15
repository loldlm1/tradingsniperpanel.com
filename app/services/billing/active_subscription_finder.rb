module Billing
  class ActiveSubscriptionFinder
    def initialize(user:)
      @user = user
    end

    def call
      return nil unless user
      return nil unless user.respond_to?(:pay_customers)
      return nil unless Pay::Customer.table_exists?

      customer = user.pay_customers.first
      return nil unless customer

      customer.subscriptions.active.order(created_at: :desc).first
    end

    private

    attr_reader :user
  end
end
