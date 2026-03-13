class User < ApplicationRecord
  has_referrals
  pay_customer default_payment_processor: :stripe, stripe_attributes: :stripe_customer_attributes
  has_many :user_expert_advisors, dependent: :destroy
  has_many :expert_advisors, through: :user_expert_advisors
  has_many :licenses, dependent: :destroy
  has_many :license_online_sessions, dependent: :destroy
  has_many :marketplace_purchases, dependent: :destroy
  has_many :manual_transactions, dependent: :destroy
  has_many :manual_subscriptions, dependent: :destroy
  has_many :course_enrollments, dependent: :destroy
  has_many :courses, through: :course_enrollments
  has_many :course_lesson_progresses, dependent: :destroy
  has_one :partner_profile, dependent: :destroy

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :role, { trader: 0, partner: 1, admin: 2, master_admin: 3, full_trader: 4 }

  attr_accessor :terms_of_service

  before_validation :set_terms_accepted_at_from_checkbox, on: :create
  validate :terms_must_be_accepted, on: :create

  after_commit :sync_role_based_access, if: :saved_change_to_role?

  def pay_customer_name
    name.presence || email
  end

  def partner_enabled?
    partner_profile&.active? || false
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

  def preferred_locale_code
    preferred_locale.presence || I18n.default_locale
  end

  def privileged_full_access?
    admin? || master_admin? || full_trader?
  end

  # Send Devise emails asynchronously so auth flows do not block on SMTP latency.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email id name preferred_locale role]
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

  def sync_role_based_access
    Licenses::PrivilegedAccess.new(user: self).sync_all
  end
end
