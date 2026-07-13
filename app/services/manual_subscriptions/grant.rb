module ManualSubscriptions
  class Grant
    MAX_GRANTED_DAYS = 730
    PANDORA_TIER = "pandora_pro".freeze
    PANDORA_EA_ID = "pandora_box".freeze

    def initialize(user:, billing_plan:, granted_days:, recorded_by_admin:, payment_status: nil,
                   amount_cents: nil, paid_at: nil, currency: "usd", payment_method: nil,
                   reference: nil, notes: nil, now: Time.current)
      @user = user
      @billing_plan = billing_plan
      @granted_days = normalize_granted_days(granted_days)
      @recorded_by_admin = recorded_by_admin
      @payment_status = payment_status
      @amount_cents = amount_cents
      @paid_at = paid_at
      @currency = currency
      @payment_method = payment_method
      @reference = reference
      @notes = notes
      @now = now
    end

    def call
      validate_contract!

      user.with_lock do
        reject_active_stripe_subscription!
        create_grant!
      end
    end

    private

    attr_reader :user, :billing_plan, :granted_days, :recorded_by_admin, :payment_status,
                :amount_cents, :paid_at, :currency, :payment_method, :reference, :notes, :now

    def validate_contract!
      raise ArgumentError, "user is required" unless user.is_a?(User) && user.persisted?
      raise ArgumentError, "Pandora subscription plan is required" unless pandora_subscription_plan?
      raise ArgumentError, "recording admin is required" unless authorized_admin?
    end

    def pandora_subscription_plan?
      billing_plan.is_a?(BillingPlan) &&
        billing_plan.persisted? &&
        billing_plan.active? &&
        billing_plan.subscription? &&
        billing_plan.tier == PANDORA_TIER &&
        billing_plan.expert_advisors.where(ea_id: PANDORA_EA_ID).exists?
    end

    def authorized_admin?
      recorded_by_admin.is_a?(User) &&
        recorded_by_admin.persisted? &&
        (recorded_by_admin.admin? || recorded_by_admin.master_admin?)
    end

    def reject_active_stripe_subscription!
      result = Billing::ActiveSubscriptionFinder.new(user: user).call
      raise ActiveRecord::RecordInvalid.new(billing_conflict_record) if result.stripe?
    end

    def billing_conflict_record
      ManualSubscription.new.tap { |record| record.errors.add(:base, :billing_conflict) }
    end

    def create_grant!
      starts_at = [ now, latest_manual_end ].compact.max
      payment = normalized_payment

      ManualSubscription.create!(
        user: user,
        billing_plan: billing_plan,
        granted_days: granted_days,
        starts_at: starts_at,
        ends_at: starts_at + granted_days.days,
        status: ManualSubscription::STATUSES[:active],
        recorded_by_admin: recorded_by_admin,
        currency: currency.to_s.downcase.presence || "usd",
        payment_status: payment.fetch(:status),
        amount_cents: payment.fetch(:amount_cents),
        paid_at: payment[:paid_at],
        payment_method: payment_method.presence,
        reference: reference.presence,
        notes: notes.presence
      )
    end

    def latest_manual_end
      user.manual_subscriptions
          .where.not(status: [ ManualSubscription::STATUSES[:cancelled], ManualSubscription::STATUSES[:superseded] ])
          .maximum(:ends_at)
    end

    def normalized_payment
      status = inferred_payment_status
      amount = normalize_amount_cents(amount_cents)

      case status
      when ManualSubscription::PAYMENT_STATUSES[:complimentary]
        raise ArgumentError, "complimentary grants must have a zero amount" unless amount.zero?
        raise ArgumentError, "complimentary grants cannot have a paid date" if paid_at.present?
        { status: status, amount_cents: 0, paid_at: nil }
      when ManualSubscription::PAYMENT_STATUSES[:pending]
        raise ArgumentError, "pending grants cannot have a paid date" if paid_at.present?
        { status: status, amount_cents: amount, paid_at: nil }
      when ManualSubscription::PAYMENT_STATUSES[:paid]
        raise ArgumentError, "paid grants require a positive amount" unless amount.positive?
        { status: status, amount_cents: amount, paid_at: paid_at || now }
      else
        raise ArgumentError, "invalid payment status"
      end
    end

    def inferred_payment_status
      return payment_status.to_s if payment_status.present?
      return ManualSubscription::PAYMENT_STATUSES[:paid] if paid_at.present?
      return ManualSubscription::PAYMENT_STATUSES[:pending] if normalize_amount_cents(amount_cents).positive?

      ManualSubscription::PAYMENT_STATUSES[:complimentary]
    end

    def normalize_granted_days(value)
      days = Integer(value, exception: false)
      return days if days&.between?(1, MAX_GRANTED_DAYS)

      raise ArgumentError, "granted_days must be between 1 and #{MAX_GRANTED_DAYS}"
    end

    def normalize_amount_cents(value)
      amount = value.presence || 0
      normalized = Integer(amount, exception: false)
      raise ArgumentError, "amount_cents must be a non-negative integer" unless normalized && normalized >= 0

      normalized
    end
  end
end
