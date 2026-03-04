class LicenseLaneMagicNumber < ApplicationRecord
  ACCOUNT_TYPES = {
    real: "real",
    demo: "demo"
  }.freeze

  belongs_to :license

  enum :account_type, ACCOUNT_TYPES, prefix: true

  validates :source, presence: true
  validates :email, presence: true
  validates :company, presence: true
  validates :account_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :account_type, presence: true
  validates :magic_number, presence: true, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
  validates :account_number, uniqueness: {
    scope: %i[license_id source email company account_type],
    message: :taken
  }

  before_validation :normalize_source
  before_validation :normalize_email
  before_validation :normalize_company

  private

  def normalize_source
    self.source = source.to_s.strip.downcase
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_company
    self.company = company.to_s.strip.downcase
  end
end
