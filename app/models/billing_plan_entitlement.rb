class BillingPlanEntitlement < ApplicationRecord
  belongs_to :billing_plan
  belongs_to :expert_advisor

  validates :billing_plan_id, uniqueness: { scope: :expert_advisor_id }
end
