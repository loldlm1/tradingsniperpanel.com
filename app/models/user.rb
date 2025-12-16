class User < ApplicationRecord
  has_referrals
  pay_customer default_payment_processor: :stripe, stripe_attributes: :stripe_customer_attributes
  has_many :user_expert_advisors, dependent: :destroy
  has_many :expert_advisors, through: :user_expert_advisors

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  after_create :ensure_referral_code

  def pay_customer_name
    name.presence || email
  end

  def stripe_customer_attributes
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
end
