class BillingEmailDelivery < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :pay_charge, class_name: "Pay::Charge", optional: true
  belongs_to :pay_subscription, class_name: "Pay::Subscription", optional: true

  validates :event_key, presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :delivered_at, presence: true
end
