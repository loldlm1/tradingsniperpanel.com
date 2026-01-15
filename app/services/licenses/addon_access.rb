module Licenses
  class AddonAccess
    Result = Struct.new(:allowed, :required, :missing, keyword_init: true) do
      def allowed?
        !!allowed
      end
    end

    def initialize(user:, expert_advisor:, addon_keys:)
      @user = user
      @expert_advisor = expert_advisor
      @addon_keys = normalize_keys(addon_keys)
    end

    def call
      return Result.new(allowed: true, required: [], missing: []) if addon_keys.empty?

      addons = Addon.where(key: addon_keys, addonable: expert_advisor)
      addons_by_key = addons.index_by(&:key)
      purchased_plan_ids = MarketplacePurchase.where(
        user: user,
        billing_plan_id: addons.select(:billing_plan_id)
      ).pluck(:billing_plan_id)

      missing_keys = addon_keys.reject do |key|
        addon = addons_by_key[key]
        addon && purchased_plan_ids.include?(addon.billing_plan_id)
      end

      Result.new(allowed: missing_keys.empty?, required: addon_keys, missing: missing_keys)
    end

    private

    attr_reader :user, :expert_advisor, :addon_keys

    def normalize_keys(keys)
      Array(keys)
        .flat_map { |value| value.to_s.split(",") }
        .map { |value| value.strip }
        .reject(&:blank?)
        .uniq
    end
  end
end
