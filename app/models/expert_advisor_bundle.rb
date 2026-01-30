class ExpertAdvisorBundle < ApplicationRecord
  BUNDLE_KEY_FORMAT = /\A[a-z0-9_]+(?:__+[a-z0-9_]+)*\z/.freeze

  belongs_to :expert_advisor
  has_one_attached :bundle_file

  validates :bundle_key, presence: true, format: { with: BUNDLE_KEY_FORMAT }
  validates :bundle_key, uniqueness: { scope: :expert_advisor_id }

  validate :bundle_key_matches_required_addons

  scope :active, -> { where(active: true) }

  def normalized_addon_keys
    required_addon_keys.to_s.split(",").map(&:strip).reject(&:blank?).uniq.sort
  end

  def expected_bundle_key
    keys = normalized_addon_keys
    keys.empty? ? "base" : keys.join("__")
  end

  def self.ransackable_associations(_auth_object = nil)
    ["expert_advisor"]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      active
      bundle_key
      created_at
      expert_advisor_id
      id
      required_addon_keys
      sort_order
      updated_at
    ]
  end

  private

  def bundle_key_matches_required_addons
    return if bundle_key.blank?

    expected = expected_bundle_key
    return if bundle_key == expected

    errors.add(:bundle_key, :invalid)
  end
end
