module Admin
  class MarketplaceProductLinker
    def initialize(subject:, marketplace_product_ids:)
      @subject = subject
      @marketplace_product_ids = normalize_ids(marketplace_product_ids)
    end

    def call
      return unless subject

      plan_ids = MarketplaceProduct.where(id: marketplace_product_ids).pluck(:billing_plan_id)
      marketplace_plan_ids = MarketplaceProduct.select(:billing_plan_id)

      case subject
      when ExpertAdvisor
        sync_entitlements(BillingPlanEntitlement, :expert_advisor_id, plan_ids, marketplace_plan_ids)
      when Course
        sync_entitlements(CoursePlanEntitlement, :course_id, plan_ids, marketplace_plan_ids)
      when MarketplaceAsset
        sync_entitlements(AssetPlanEntitlement, :marketplace_asset_id, plan_ids, marketplace_plan_ids)
      end
    end

    private

    attr_reader :subject, :marketplace_product_ids

    def sync_entitlements(model, foreign_key, desired_plan_ids, marketplace_plan_ids)
      scope = model.where(foreign_key => subject.id, billing_plan_id: marketplace_plan_ids)
      current_plan_ids = scope.pluck(:billing_plan_id)
      remove_ids = current_plan_ids - desired_plan_ids
      add_ids = desired_plan_ids - current_plan_ids

      if remove_ids.any?
        model.where(foreign_key => subject.id, billing_plan_id: remove_ids).delete_all
      end

      add_ids.each do |plan_id|
        model.create!(foreign_key => subject.id, billing_plan_id: plan_id)
      end
    end

    def normalize_ids(value)
      Array(value).map(&:to_s).map(&:strip).reject(&:blank?).map(&:to_i).uniq
    end
  end
end
