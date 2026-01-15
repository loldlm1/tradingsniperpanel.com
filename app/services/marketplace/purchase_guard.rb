module Marketplace
  class PurchaseGuard
    Result = Struct.new(:allowed, :purchase, :reason, :addonable, keyword_init: true)

    def initialize(user:, billing_plan:)
      @user = user
      @billing_plan = billing_plan
    end

    def call
      return Result.new(allowed: true) unless user && billing_plan

      purchase = MarketplacePurchase.find_by(user: user, billing_plan: billing_plan)
      return Result.new(allowed: false, purchase: purchase, reason: :already_purchased) if purchase

      addon = billing_plan.addon
      if addon
        eligibility = Addons::Eligibility.new(user: user, addon: addon).call
        return Result.new(
          allowed: false,
          reason: eligibility.reason,
          addonable: eligibility.addonable
        ) unless eligibility.allowed?
      end

      Result.new(allowed: true)
    end

    private

    attr_reader :user, :billing_plan
  end
end
