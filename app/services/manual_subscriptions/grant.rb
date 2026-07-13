module ManualSubscriptions
  class Grant
    class IdempotencyConflict < StandardError; end

    MAX_GRANTED_DAYS = 730
    PANDORA_EA_ID = "pandora_box".freeze

    def initialize(user:, billing_plan:, granted_days:, recorded_by_admin:, request_id:, payment_status: nil,
                   amount_cents: nil, paid_at: nil, currency: "usd", payment_method: nil,
                   reference: nil, notes: nil, now: Time.current)
      @user = user
      @billing_plan = billing_plan
      @granted_days = normalize_granted_days(granted_days)
      @recorded_by_admin = recorded_by_admin
      @request_id = request_id.to_s
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
      return grant_from(existing_event) if existing_event

      user.with_lock do
        reject_active_stripe_subscription!
        grant = create_grant!
        AdminAuditEvent.create!(
          actor: recorded_by_admin,
          action: AdminAuditEvent::ACTIONS.fetch(:manual_subscription_granted),
          target: user,
          request_id: request_id,
          metadata: {
            "manual_subscription_id" => grant.id,
            "billing_plan_id" => billing_plan.id,
            "granted_days" => grant.granted_days,
            "payment_status" => grant.payment_status,
            "amount_cents" => grant.amount_cents,
            "currency" => grant.currency,
            "starts_at" => grant.starts_at.iso8601(6),
            "ends_at" => grant.ends_at.iso8601(6)
          }
        )
        grant
      end
    rescue ActiveRecord::RecordNotUnique
      grant_from(existing_event!)
    end

    private

    attr_reader :user, :billing_plan, :granted_days, :recorded_by_admin, :request_id, :payment_status,
                :amount_cents, :paid_at, :currency, :payment_method, :reference, :notes, :now

    def validate_contract!
      raise ArgumentError, "user is required" unless user.is_a?(User) && user.persisted?
      raise ArgumentError, "Pandora subscription plan is required" unless pandora_subscription_plan?
      raise ArgumentError, "recording admin is required" unless authorized_admin?
      raise ArgumentError, "request_id is required" if request_id.blank? || request_id.length > 128
    end

    def pandora_subscription_plan?
      billing_plan.is_a?(BillingPlan) &&
        billing_plan.persisted? &&
        BillingPlan.purchasable.exists?(id: billing_plan.id) &&
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
        currency: normalized_currency,
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

    def existing_event
      event = AdminAuditEvent.find_by(request_id: request_id)
      return unless event
      return event if matching_event?(event)

      raise IdempotencyConflict, "request_id was already used for another admin operation"
    end

    def existing_event!
      existing_event || raise(IdempotencyConflict, "admin operation could not be recovered")
    end

    def matching_event?(event)
      payment = normalized_payment
      metadata = event.metadata

      event.actor_id == recorded_by_admin.id &&
        event.action == AdminAuditEvent::ACTIONS.fetch(:manual_subscription_granted) &&
        event.target_type == "User" &&
        event.target_id == user.id &&
        Integer(metadata["billing_plan_id"], exception: false) == billing_plan.id &&
        Integer(metadata["granted_days"], exception: false) == granted_days &&
        metadata["payment_status"] == payment.fetch(:status) &&
        Integer(metadata["amount_cents"], exception: false) == payment.fetch(:amount_cents) &&
        metadata["currency"] == normalized_currency
    end

    def normalized_currency
      currency.to_s.downcase.presence || "usd"
    end

    def grant_from(event)
      grant_id = Integer(event.metadata["manual_subscription_id"], exception: false)
      raise IdempotencyConflict, "manual grant could not be recovered" unless grant_id

      ManualSubscription.find(grant_id)
    end
  end
end
