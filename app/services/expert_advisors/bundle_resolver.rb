module ExpertAdvisors
  class BundleResolver
    Result = Struct.new(:bundle, :bundle_key, :addon_keys, :missing_bundle, keyword_init: true) do
      def found?
        bundle.present?
      end
    end

    def initialize(user:, expert_advisor:)
      @user = user
      @expert_advisor = expert_advisor
    end

    def call
      return Result.new(bundle_key: "base", addon_keys: [], missing_bundle: false) unless expert_advisor && user

      addon_keys = purchased_addon_keys
      requested_bundle_key = addon_keys.empty? ? "base" : addon_keys.join("__")
      bundle = resolve_bundle(requested_bundle_key)

      if bundle
        return Result.new(bundle: bundle, bundle_key: bundle.bundle_key, addon_keys: addon_keys, missing_bundle: false)
      end

      Result.new(bundle_key: requested_bundle_key, addon_keys: addon_keys, missing_bundle: true)
    end

    private

    attr_reader :user, :expert_advisor

    def resolve_bundle(requested_bundle_key)
      exact_bundle = bundle_for(requested_bundle_key)
      return exact_bundle if exact_bundle
      return nil if requested_bundle_key == "base"

      bundle_for("base")
    end

    def bundle_for(bundle_key)
      bundle = expert_advisor.expert_advisor_bundles.active.find_by(bundle_key: bundle_key)
      return nil unless bundle&.bundle_file&.attached?

      bundle
    end

    def purchased_addon_keys
      addons = Addon.where(addonable: expert_advisor).pluck(:key, :billing_plan_id)
      return [] if addons.empty?

      plan_ids = addons.map(&:last)
      purchased_ids = MarketplacePurchase.where(user: user, billing_plan_id: plan_ids).pluck(:billing_plan_id)

      addons.each_with_object([]) do |(key, plan_id), keys|
        keys << key if purchased_ids.include?(plan_id)
      end.sort
    end
  end
end
