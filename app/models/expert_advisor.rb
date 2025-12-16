class ExpertAdvisor < ApplicationRecord
  enum ea_type: { ea_robot: 0, ea_tool: 1 }

  has_many :user_expert_advisors, dependent: :destroy

  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil) }

  def active_documents
    documents || {}
  end

  def allowed_for_tier?(tier)
    return true if allowed_subscription_tiers.blank?

    Array(allowed_subscription_tiers).map(&:to_s).include?(tier.to_s)
  end
end
