class ProductReleaseItem < ApplicationRecord
  belongs_to :product_release
  belongs_to :subject, polymorphic: true, optional: true

  enum :product_kind, {
    expert_advisor: "expert_advisor",
    addon: "addon",
    course: "course"
  }

  enum :action_type, {
    added: "added",
    updated: "updated"
  }

  validates :title_en, :title_es, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.ransackable_associations(_auth_object = nil)
    %w[product_release subject]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[action_type created_at id position product_kind subject_id subject_type title_en title_es updated_at]
  end

  def title_for(locale)
    case locale.to_s
    when "es"
      title_es.presence || title_en
    else
      title_en.presence || title_es
    end
  end
end
