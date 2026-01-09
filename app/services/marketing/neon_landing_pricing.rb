module Marketing
  class NeonLandingPricing
    MAX_TIERS = 3

    def call
      catalog = Billing::PricingCatalog.new.call
      return {} if catalog.blank?

      tiers = build_tiers(catalog)
      return {} if tiers.empty?

      intervals = Billing::PricingCatalog.filter_intervals(
        intervals: catalog[:intervals],
        prices: catalog[:prices],
        tiers: tiers.map { |tier| tier[:key] }
      )
      return {} if intervals.empty?

      prices = Billing::PricingCatalog.filter_prices(
        prices: catalog[:prices],
        intervals: intervals,
        tiers: tiers.map { |tier| tier[:key] }
      )

      {
        intervals: intervals,
        prices: prices,
        tiers: tiers,
        discount_percent: catalog[:discount_percent]
      }
    end

    private

    def build_tiers(catalog)
      tier_keys = Array(catalog[:tiers]).map(&:to_s).first(MAX_TIERS)
      return [] if tier_keys.empty?

      plans = BillingPlan.subscription.active.where(tier: tier_keys)
      plans_by_tier = plans.group_by(&:tier)

      tier_keys.map.with_index do |tier, index|
        plan = plans_by_tier[tier]&.min_by { |record| [record.sort_order.to_i, record.amount_cents.to_i] }
        {
          key: tier,
          name: tier_name(tier),
          description: tier_description(tier, plan),
          features_title: tier_features_title(tier),
          features: tier_features(tier),
          featured: index == 1
        }
      end
    end

    def tier_name(tier)
      I18n.t("landing.neon.pricing.tiers.#{tier}.name", default: tier.to_s.humanize)
    end

    def tier_description(tier, plan)
      from_i18n = I18n.t("landing.neon.pricing.tiers.#{tier}.description", default: nil)
      return from_i18n if from_i18n.present?

      plan&.description
    end

    def tier_features_title(tier)
      I18n.t("landing.neon.pricing.tiers.#{tier}.features_title", default: nil)
    end

    def tier_features(tier)
      Array(I18n.t("landing.neon.pricing.tiers.#{tier}.features", default: []))
    end
  end
end
