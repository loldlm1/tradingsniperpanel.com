require "securerandom"

class ExpertAdvisor < ApplicationRecord
  enum :ea_type, { ea_robot: 0, ea_tool: 1 }

  has_many :user_expert_advisors, dependent: :destroy
  has_many :licenses, dependent: :destroy

  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil) }
  scope :ordered_by_rank, -> { order(:tier_rank, :name) }

  before_validation :assign_ea_id, on: :create

  validates :ea_id, presence: true, uniqueness: true
  validates :tier_rank, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # Prevent accidental EA identifier changes once issued
  validate :ea_id_immutable, on: :update

  def active_documents
    documents || {}
  end

  def to_param
    ea_id
  end

  def allowed_for_tier?(tier)
    return true if allowed_subscription_tiers.blank?

    Array(allowed_subscription_tiers).map(&:to_s).include?(tier.to_s)
  end

  private

  def assign_ea_id
    return if ea_id.present?

    base = name.to_s.parameterize.presence || "expert-advisor"
    self.ea_id = "#{base}-#{SecureRandom.hex(4)}"
  end

  def ea_id_immutable
    return unless ea_id_changed?

    errors.add(:ea_id, :immutable)
  end
end
