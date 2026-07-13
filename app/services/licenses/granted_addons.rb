require "set"

module Licenses
  class GrantedAddons
    def initialize(user:, expert_advisor:)
      @user = user
      @expert_advisor = expert_advisor
    end

    def call
      return [] unless user.is_a?(User)
      return [] unless expert_advisor.is_a?(ExpertAdvisor)

      addon_pairs = Addon.where(addonable: expert_advisor)
                         .order(:key)
                         .pluck(:key, :billing_plan_id)
      return [] if addon_pairs.empty?

      normalized_pairs = addon_pairs.map { |key, plan_id| [normalize_key(key), plan_id] }

      purchased_plan_ids = MarketplacePurchase.where(
        user: user,
        billing_plan_id: normalized_pairs.map(&:last)
      ).pluck(:billing_plan_id).to_set

      normalized_pairs.filter_map do |normalized_key, plan_id|
        normalized_key if purchased_plan_ids.include?(plan_id)
      end.uniq
    end

    private

    attr_reader :user, :expert_advisor

    def normalize_key(key)
      key.to_s.strip.downcase
    end
  end
end
