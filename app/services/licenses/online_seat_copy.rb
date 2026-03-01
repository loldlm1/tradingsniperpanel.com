module Licenses
  class OnlineSeatCopy
    class << self
      def subscription_feature_for_tier(tier, locale: I18n.locale)
        cap = subscription_cap_for_tier(tier)
        return nil unless cap

        I18n.t("licenses.online_seats.subscription_feature", count: cap, locale: locale)
      end

      def one_time_feature(locale: I18n.locale)
        I18n.t(
          "licenses.online_seats.one_time_feature",
          count: Licenses::OnlineSeatLimits::ONE_TIME_CAP_PER_EA,
          locale: locale
        )
      end

      def subscription_cap_for_tier(tier)
        tier_rank = ordered_tiers.index(tier.to_s)
        return nil if tier_rank.nil?

        base_plus_rank = Licenses::OnlineSeatLimits::BASE_SUBSCRIPTION_CAP + tier_rank
        [base_plus_rank, Licenses::OnlineSeatLimits::MAX_SUBSCRIPTION_CAP].min
      end

      private

      def ordered_tiers
        BillingPlan.subscription_tiers.map { |plan| plan.tier.to_s }
      end
    end
  end
end
