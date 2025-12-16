class UserExpertAdvisor < ApplicationRecord
  belongs_to :user
  belongs_to :expert_advisor

  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
end
