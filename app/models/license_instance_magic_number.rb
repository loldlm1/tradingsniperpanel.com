class LicenseInstanceMagicNumber < ApplicationRecord
  INSTANCE_ID_FORMAT = /\A[A-Za-z0-9_-]+\z/
  MAX_INSTANCE_ID_LENGTH = 64

  belongs_to :license
  belongs_to :broker_account
  belongs_to :expert_advisor

  validates :source, presence: true
  validates :email, presence: true
  validates :instance_id, presence: true, length: { maximum: MAX_INSTANCE_ID_LENGTH }, format: {
    with: INSTANCE_ID_FORMAT
  }
  validates :magic_number, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: Licenses::MagicNumberPolicy::MIN_VALUE,
    less_than_or_equal_to: Licenses::MagicNumberPolicy::MAX_VALUE
  }
  validates :instance_id, uniqueness: { scope: %i[broker_account_id expert_advisor_id] }
  validates :magic_number, uniqueness: { scope: :broker_account_id }
  validate :expert_advisor_matches_license

  before_validation :normalize_source
  before_validation :normalize_email
  before_validation :normalize_instance_id

  def transport_safe_magic_number?
    Licenses::MagicNumberPolicy.supported?(magic_number)
  end

  private

  def normalize_source
    self.source = source.to_s.strip.downcase
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_instance_id
    self.instance_id = instance_id.to_s.strip
  end

  def expert_advisor_matches_license
    return if license.blank? || expert_advisor.blank?
    return if license.expert_advisor_id == expert_advisor.id

    errors.add(:expert_advisor, :invalid)
  end
end
