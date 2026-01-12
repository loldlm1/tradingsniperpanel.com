module Licenses
  class OneTimePurchaseSync
    def initialize(pay_charge_id:, encoder: LicenseKeyEncoder.new, logger: Rails.logger)
      @pay_charge_id = pay_charge_id
      @encoder = encoder
      @logger = logger
    end

    def call
      charge = Pay::Charge.find_by(id: pay_charge_id)
      return unless charge
      return if charge.subscription_id.present?

      plan = resolve_plan(charge)
      return unless plan&.one_time?

      customer = charge.customer
      user = customer&.owner
      return unless user.is_a?(User)

      record_marketplace_purchase(user: user, plan: plan, charge: charge)

      plan.expert_advisors.find_each do |expert_advisor|
        grant_license(user: user, expert_advisor: expert_advisor)
      end

      plan.courses.find_each do |course|
        grant_course_access(user: user, course: course, charge: charge)
      end

      mark_referral_completed(user: user, charge: charge)
    rescue StandardError => e
      logger.error("[Licenses::OneTimePurchaseSync] failed pay_charge_id=#{pay_charge_id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :pay_charge_id, :encoder, :logger

    def resolve_plan(charge)
      metadata = (charge.metadata || {}).to_h.stringify_keys
      key = metadata["billing_plan_key"] || metadata["price_key"] || metadata["plan_key"]
      return BillingPlan.for_key(key) if key.present?

      price_id = metadata["stripe_price_id"] || metadata["price_id"] || extract_price_id(charge)
      plan = BillingPlan.for_price_id(price_id)
      return plan if plan

      product_id = metadata["stripe_product_id"] || metadata["product_id"] || extract_product_id(charge)
      BillingPlan.for_product_id(product_id)
    end

    def extract_price_id(charge)
      extract_nested_value(charge.data, "price_") || extract_nested_value(charge.object, "price_")
    end

    def extract_product_id(charge)
      extract_nested_value(charge.data, "prod_") || extract_nested_value(charge.object, "prod_")
    end

    def extract_nested_value(payload, prefix)
      return if payload.blank?

      if payload.is_a?(Hash)
        payload.each_value do |value|
          found = extract_nested_value(value, prefix)
          return found if found.present?
        end

        payload.each do |key, value|
          next unless key.to_s.include?("price") || key.to_s.include?("product")

          if value.is_a?(String) && value.start_with?(prefix)
            return value
          end
        end
      elsif payload.is_a?(Array)
        payload.each do |value|
          found = extract_nested_value(value, prefix)
          return found if found.present?
        end
      elsif payload.is_a?(String) && payload.start_with?(prefix)
        return payload
      end

      nil
    end

    def grant_license(user:, expert_advisor:)
      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
      license.with_lock do
        license.access_source = "one_time"
        license.plan_interval = nil
        license.source = "stripe_charge"
        license.last_synced_at = Time.current
        license.trial_ends_at = nil
        license.expires_at = nil
        license.status = "active"
        license.encrypted_key = encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: nil)
        license.save!
      end
    end

    def grant_course_access(user:, course:, charge:)
      enrollment = CourseEnrollment.find_or_initialize_by(user: user, course: course)
      enrollment.access_source = "one_time"
      enrollment.purchased_at ||= charge.created_at || Time.current
      enrollment.pay_charge_id ||= charge.id
      enrollment.save!
    end

    def record_marketplace_purchase(user:, plan:, charge:)
      product = MarketplaceProduct.find_by(billing_plan_id: plan.id)
      return unless product

      purchase = MarketplacePurchase.find_or_initialize_by(user: user, billing_plan: plan)
      return if purchase.persisted?

      purchase.pay_charge = charge
      purchase.purchased_at = charge.created_at || Time.current
      purchase.save!
    end

    def mark_referral_completed(user:, charge:)
      Referrals::MarkCompleted.new(user: user).call
    rescue StandardError => e
      logger.warn("[Licenses::OneTimePurchaseSync] referral completion failed pay_charge_id=#{charge.id}: #{e.class} - #{e.message}")
    end
  end
end
