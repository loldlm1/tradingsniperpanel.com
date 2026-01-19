class AssetPlanEntitlement < ApplicationRecord
  belongs_to :billing_plan
  belongs_to :marketplace_asset

  validates :billing_plan_id, uniqueness: { scope: :marketplace_asset_id }
  validate :billing_plan_is_supported

  private

  def billing_plan_is_supported
    return if billing_plan&.subscription? || billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end
end
