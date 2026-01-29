class BillingPlanEntitlement < ApplicationRecord
  belongs_to :billing_plan
  belongs_to :expert_advisor

  validates :billing_plan_id, uniqueness: { scope: :expert_advisor_id }

  def self.ransackable_associations(_auth_object = nil)
    %w[billing_plan expert_advisor]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[billing_plan_id created_at expert_advisor_id id updated_at]
  end
end
