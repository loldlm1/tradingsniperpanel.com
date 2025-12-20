class BrokerAccount < ApplicationRecord
  enum :account_type, { real: 0, demo: 1 }

  belongs_to :license

  validates :company, presence: true
  validates :account_number, presence: true, numericality: { only_integer: true }
  validates :account_type, presence: true
  validates :account_number, uniqueness: { scope: [:company, :account_type] }
end
