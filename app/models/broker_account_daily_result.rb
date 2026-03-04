class BrokerAccountDailyResult < ApplicationRecord
  belongs_to :broker_account
  belongs_to :expert_advisor

  validates :expert_advisor, presence: true
  validates :magic_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :result_timestamp, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :result_value, presence: true, numericality: true
  validate :result_value_scale

  scope :in_range, lambda { |from_ts, to_ts|
    return none if from_ts.blank? || to_ts.blank?

    where(result_timestamp: from_ts..to_ts)
  }

  def self.daily_totals(from_ts:, to_ts:)
    in_range(from_ts, to_ts)
      .group("date_trunc('day', to_timestamp(result_timestamp) AT TIME ZONE 'UTC')")
      .sum(:result_value)
      .transform_keys { |ts| ts.to_date }
  end

  def result_on
    return nil if result_timestamp.blank?

    Time.at(result_timestamp).utc.to_date
  end

  private

  def result_value_scale
    return if result_value.blank?
    return if result_value.scale <= 2

    errors.add(:result_value, "must have at most 2 decimal places")
  end
end
