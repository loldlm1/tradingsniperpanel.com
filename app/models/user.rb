class User < ApplicationRecord
  has_referrals
  pay_customer default_payment_processor: :stripe, stripe_attributes: :stripe_customer_attributes
  has_many :user_expert_advisors, dependent: :destroy
  has_many :expert_advisors, through: :user_expert_advisors
  has_many :licenses, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :role, { trader: 0, partner: 1, admin: 2 }

  attr_accessor :terms_of_service

  before_validation :set_terms_accepted_at_from_checkbox, on: :create
  validate :terms_must_be_accepted, on: :create

  after_commit :ensure_referral_code_for_partner, on: :create
  after_commit :ensure_referral_code_for_new_partner, if: -> { saved_change_to_role? && partner? }
  after_commit :enqueue_trial_licenses, on: :create

  def pay_customer_name
    name.presence || email
  end

  def stripe_customer_attributes(_pay_customer = nil)
    {
      email: email,
      metadata: {
        user_id: id,
        referral_code: referral_codes.first&.code,
        preferred_locale: preferred_locale
      }.compact
    }
  end

  def ensure_referral_code
    referral_codes.first_or_create
  end

  def ensure_referral_code_if_referred!
    ensure_referral_code if referrer.present?
  end

  def ensure_referral_code_for_partner
    ensure_referral_code if partner?
  end

  def ensure_referral_code_for_new_partner
    ensure_referral_code
  end

  def preferred_locale_code
    preferred_locale.presence || I18n.default_locale
  end

  private

  def set_terms_accepted_at_from_checkbox
    return if terms_accepted_at.present?

    if ActiveModel::Type::Boolean.new.cast(terms_of_service)
      self.terms_accepted_at = Time.current
    end
  end

  def terms_must_be_accepted
    return if terms_accepted_at.present?

    errors.add(:terms_of_service, :accepted)
  end

  def enqueue_trial_licenses
    Licenses::CreateTrialLicensesJob.perform_later(id)
  end
end
