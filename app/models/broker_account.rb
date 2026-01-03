class BrokerAccount < ApplicationRecord
  enum :account_type, { real: 0, demo: 1 }

  belongs_to :license
  has_many :broker_account_daily_results, dependent: :destroy

  validates :company, presence: true
  validates :account_number, presence: true, numericality: { only_integer: true }
  validates :account_type, presence: true
  validates :account_number, uniqueness: { scope: [:company, :account_type] }
end
