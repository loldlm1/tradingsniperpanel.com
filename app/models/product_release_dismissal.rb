class ProductReleaseDismissal < ApplicationRecord
  belongs_to :product_release
  belongs_to :user

  validates :dismissed_at, presence: true
  validates :user_id, uniqueness: { scope: :product_release_id }

  def self.ransackable_associations(_auth_object = nil)
    %w[product_release user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at dismissed_at id product_release_id updated_at user_id]
  end
end
