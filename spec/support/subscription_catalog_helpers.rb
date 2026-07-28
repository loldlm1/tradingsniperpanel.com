module SubscriptionCatalogHelpers
  def create_subscription_catalog
    expert_advisors = {}
    Billing::SubscriptionCatalog.products.each do |product|
      product.ea_ids.each do |ea_id|
        ea_product = Billing::SubscriptionCatalog.product_for_catalog_key(ea_id)
        expert_advisor = ExpertAdvisor.find_or_initialize_by(ea_id: ea_id)
        expert_advisor.assign_attributes(
          name: ea_product.product_name,
          ea_type: :ea_tool,
          tier_rank: ea_product.access_rank,
          trial_enabled: false,
          allowed_subscription_tiers: []
        )
        expert_advisor.save!
        expert_advisors[ea_id] = expert_advisor
      end
    end

    plans = {}
    Billing::SubscriptionCatalog.products.each do |product|
      product.plan_definitions.each do |key, definition|
        plan = BillingPlan.find_or_initialize_by(key: key)
        plan.assign_attributes(
          name: plan.name.presence || "#{product.product_name} #{key}",
          tier: product.tier,
          kind: "subscription",
          interval: definition.fetch(:interval),
          interval_count: definition.fetch(:interval_count),
          amount_cents: definition.fetch(:amount_cents),
          currency: product.currency,
          active: true,
          sort_order: product.sort_order,
          stripe_product_id: plan.stripe_product_id.presence || "prod_spec_#{product.catalog_key}",
          stripe_price_id: plan.stripe_price_id.presence || "price_spec_#{key}"
        )
        plan.save!
        product.ea_ids.each do |ea_id|
          BillingPlanEntitlement.find_or_create_by!(billing_plan: plan, expert_advisor: expert_advisors.fetch(ea_id))
        end
        plans[key] = plan
      end
    end

    {
      plans: plans,
      expert_advisors: expert_advisors,
      chu_monthly: plans.fetch(Billing::ChuSniperPricing::MONTHLY_KEY),
      chu_annual: plans.fetch(Billing::ChuSniperPricing::ANNUAL_KEY),
      pandora_monthly: plans.fetch(Billing::PandoraPricing::MONTHLY_KEY),
      pandora_annual: plans.fetch(Billing::PandoraPricing::ANNUAL_KEY)
    }
  end
end

RSpec.configure do |config|
  config.include SubscriptionCatalogHelpers
end
