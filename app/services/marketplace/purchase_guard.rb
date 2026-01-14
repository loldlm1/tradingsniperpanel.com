module Marketplace
  class PurchaseGuard
    Result = Struct.new(:allowed, :purchase, keyword_init: true)

    def initialize(user:, billing_plan:)
      @user = user
      @billing_plan = billing_plan
    end

    def call
      return Result.new(allowed: true) unless user && billing_plan

      purchase = MarketplacePurchase.find_by(user: user, billing_plan: billing_plan)
      Result.new(allowed: purchase.nil?, purchase: purchase)
    end

    private

    attr_reader :user, :billing_plan
  end
end
