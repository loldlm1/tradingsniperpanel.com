class RevenueSplitRule < ApplicationRecord
  validates :effective_at, presence: true
  validates :us_percent, :client_percent, presence: true,
                                           numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :percentages_sum_to_100

  scope :ordered, -> { order(effective_at: :desc) }

  def self.current(as_of: Time.current)
    ordered.where("effective_at <= ?", as_of).first
  end

  private

  def percentages_sum_to_100
    total = us_percent.to_i + client_percent.to_i
    return if total == 100

    errors.add(:base, :invalid)
  end
end
