class PartnerProfile < ApplicationRecord
  REFERRAL_CODE_FORMAT = /\A[A-Z0-9][A-Z0-9_-]*\z/.freeze

  belongs_to :user
  has_many :partner_memberships, dependent: :destroy
  has_many :partner_commissions, dependent: :destroy
  has_many :partner_payout_requests, dependent: :destroy

  enum :payout_mode, { once_paid: 0, concurrent: 1 }

  scope :active, -> { where(active: true) }

  validates :user_id, uniqueness: true
  validates :referral_code, presence: true, format: { with: REFERRAL_CODE_FORMAT }, uniqueness: { case_sensitive: false }
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :commission_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :payout_mode, presence: true
  validate :user_id_immutable, on: :update

  before_validation :normalize_referral_code
  before_validation :set_defaults
  after_commit :sync_referral_code_record!, if: :sync_referral_code_record?

  def self.ransackable_associations(_auth_object = nil)
    ["user"]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[active commission_percent created_at discount_percent id payout_mode referral_code started_at updated_at user_id]
  end

  def active?
    active
  end

  def discount_percent_or_default
    discount_percent.presence || default_discount_percent
  end

  def commission_percent_or_default
    commission_percent.presence || default_commission_percent
  end

  private

  def normalize_referral_code
    self.referral_code = referral_code.to_s.strip.upcase.presence
  end

  def set_defaults
    self.discount_percent = default_discount_percent if discount_percent.nil?
    self.commission_percent = default_commission_percent if commission_percent.nil?
    self.referral_code = existing_referral_code || generate_unique_referral_code if referral_code.blank?
    self.payout_mode ||= :once_paid
    self.started_at ||= Time.current
    self.active = true if active.nil?
  end

  def default_discount_percent
    ENV.fetch("REFER_DEFAULT_DISCOUNT_PERCENT", "0").to_i
  end

  def default_commission_percent
    ENV.fetch("REFER_DEFAULT_COMMISSION_PERCENT", discount_percent_or_default.to_s).to_i
  end

  def existing_referral_code
    user&.referral_codes&.order(:created_at, :id)&.pick(:code)&.to_s&.strip&.upcase&.presence
  end

  def generate_unique_referral_code
    loop do
      candidate = "PART#{SecureRandom.alphanumeric(8).upcase}"
      next if self.class.where.not(id: id).exists?(referral_code: candidate)
      next if Refer::ReferralCode.exists?(code: candidate)

      return candidate
    end
  end

  def sync_referral_code_record?
    saved_change_to_referral_code? || saved_change_to_user_id?
  end

  def sync_referral_code_record!
    return unless user.is_a?(User)
    return if referral_code.blank?

    primary = user.referral_codes.order(:created_at, :id).first_or_initialize
    if primary.new_record? || primary.code != referral_code
      primary.code = referral_code
      primary.save!
    end

    user.referral_codes.where.not(id: primary.id).order(:created_at, :id).each_with_index do |code_record, index|
      retired_code = retired_duplicate_code(index)
      next if code_record.code == retired_code

      code_record.update!(code: retired_code)
    end
  rescue StandardError => e
    Rails.logger.warn("[PartnerProfile] failed to sync referral code profile_id=#{id}: #{e.class} - #{e.message}")
  end

  def retired_duplicate_code(index)
    loop do
      candidate = "OLD#{index + 1}#{SecureRandom.alphanumeric(10).upcase}"
      next if candidate == referral_code
      next if Refer::ReferralCode.exists?(code: candidate)

      return candidate
    end
  end

  def user_id_immutable
    return unless will_save_change_to_user_id?

    errors.add(:user_id, :invalid)
  end
end
