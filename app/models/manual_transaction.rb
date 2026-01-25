class ManualTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :billing_plan
  belongs_to :recorded_by_admin, class_name: "User"

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, :paid_at, presence: true
  validates :billing_plan_id, uniqueness: { scope: :user_id }

  validate :billing_plan_is_one_time
  validate :no_stripe_charge_conflict

  after_commit :enqueue_fulfillment, on: :create

  def self.ransackable_associations(_auth_object = nil)
    %w[billing_plan recorded_by_admin user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[billing_plan_id created_at id paid_at recorded_by_admin_id user_id]
  end

  private

  def billing_plan_is_one_time
    return if billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end

  def no_stripe_charge_conflict
    return unless user && billing_plan
    return unless MarketplacePurchase.table_exists?

    conflict = MarketplacePurchase.where(user: user, billing_plan: billing_plan)
                                  .where.not(pay_charge_id: nil)
                                  .exists?
    errors.add(:base, :billing_conflict) if conflict
  end

  def enqueue_fulfillment
    ManualTransactions::FulfillmentJob.perform_later(id)
  end
end
