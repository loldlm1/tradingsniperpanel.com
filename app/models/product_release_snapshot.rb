class ProductReleaseSnapshot < ApplicationRecord
  enum :product_kind, {
    expert_advisor: "expert_advisor",
    addon: "addon",
    course: "course"
  }

  validates :subject_type, :subject_id, :product_kind, :signature, :tracked_at, presence: true
  validates :subject_id, uniqueness: { scope: [:subject_type, :product_kind] }

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id product_kind signature subject_id subject_type tracked_at updated_at]
  end
end
