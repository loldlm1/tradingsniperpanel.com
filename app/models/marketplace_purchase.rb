class MarketplacePurchase < ApplicationRecord
  belongs_to :user
  belongs_to :billing_plan
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true

  validates :purchased_at, presence: true
  validates :billing_plan_id, uniqueness: { scope: :user_id }

  validate :billing_plan_is_one_time

  private

  def billing_plan_is_one_time
    return if billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end
end
