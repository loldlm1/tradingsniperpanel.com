class ProductRelease < ApplicationRecord
  belongs_to :published_by, class_name: "User", optional: true

  has_many :product_release_items, -> { order(:position, :id) }, dependent: :destroy
  has_many :product_release_dismissals, dependent: :destroy

  validates :published_at, presence: true

  scope :latest_first, -> { order(published_at: :desc, id: :desc) }

  def self.ransackable_associations(_auth_object = nil)
    %w[product_release_items published_by]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id published_at published_by_id updated_at]
  end
end
