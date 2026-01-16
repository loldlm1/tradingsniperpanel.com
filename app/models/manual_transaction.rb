class ManualTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :billing_plan
  belongs_to :recorded_by_admin, class_name: "User"

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, :paid_at, presence: true
  validates :billing_plan_id, uniqueness: { scope: :user_id }

  validate :billing_plan_is_one_time

  after_commit :enqueue_fulfillment, on: :create

  private

  def billing_plan_is_one_time
    return if billing_plan&.one_time?

    errors.add(:billing_plan, :invalid)
  end

  def enqueue_fulfillment
    ManualTransactions::FulfillmentJob.perform_later(id)
  end
end
