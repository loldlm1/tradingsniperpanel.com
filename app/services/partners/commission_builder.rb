module Partners
  class CommissionBuilder
    def initialize(pay_charge_id:, logger: Rails.logger)
      @pay_charge_id = pay_charge_id
      @logger = logger
    end

    def call
      charge = Pay::Charge.find_by(id: pay_charge_id)
      return unless charge

      user = charge.customer&.owner
      return unless user.is_a?(User)

      membership = Partners::MembershipManager.new.assign_membership_for(user)
      return unless membership

      profile = membership.partner_profile
      return unless profile&.active?
      redemption_state = Referrals::RedemptionState.new(user: user)
      return unless redemption_state.owned_by?(profile.user)

      percent = profile.commission_percent_or_default.to_i
      return unless percent.positive?

      existing = PartnerCommission.find_by(partner_profile: profile, pay_charge: charge)
      return existing if existing

      subscription = charge.subscription
      commission_kind = determine_kind(profile:, membership:, subscription:)
      return unless commission_kind

      net_cents, currency = net_amount_for(charge)
      return unless net_cents && net_cents.positive?

      occurred_at = charge.created_at || Time.current
      referral = redemption_state.referral

      if referral.present?
        referral.with_lock do
          referral.reload
          return if reward_already_consumed?(profile:, user:, charge:)
          return if referral.completed_at.present? && referral.completed_at < occurred_at

          build_commission(
            profile:,
            membership:,
            user:,
            referral:,
            charge:,
            subscription:,
            commission_kind:,
            amount_cents: ((net_cents * percent) / 100.0).round,
            currency: currency || "usd",
            percent:,
            occurred_at:,
            net_cents:
          )
        end
      else
        build_commission(
          profile:,
          membership:,
          user:,
          referral:,
          charge:,
          subscription:,
          commission_kind:,
          amount_cents: ((net_cents * percent) / 100.0).round,
          currency: currency || "usd",
          percent:,
          occurred_at:,
          net_cents:
        )
      end
    rescue StandardError => e
      logger.warn("[Partners::CommissionBuilder] failed pay_charge_id=#{pay_charge_id}: #{e.class} - #{e.message}")
      nil
    end

    private

    attr_reader :pay_charge_id, :logger

    def determine_kind(profile:, membership:, subscription:)
      return :initial unless subscription

      existing_initial = PartnerCommission.exists?(
        partner_profile: profile,
        partner_membership: membership,
        pay_subscription: subscription,
        commission_kind: :initial
      )

      if existing_initial
        return nil if profile.once_paid?
        :renewal
      else
        :initial
      end
    end

    def reward_already_consumed?(profile:, user:, charge:)
      PartnerCommission.where(partner_profile: profile, referred_user: user)
                       .where.not(pay_charge_id: charge.id)
                       .exists?
    end

    def build_commission(profile:, membership:, user:, referral:, charge:, subscription:, commission_kind:, amount_cents:, currency:, percent:, occurred_at:, net_cents:)
      return if amount_cents <= 0

      PartnerCommission.create!(
        partner_profile: profile,
        partner_membership: membership,
        referred_user: user,
        referral: referral,
        pay_charge: charge,
        pay_subscription: subscription,
        commission_kind: commission_kind,
        amount_cents: amount_cents,
        currency: currency,
        percent_applied: percent,
        status: :pending,
        occurred_at: occurred_at,
        metadata: {
          discount_percent: profile.discount_percent_or_default,
          commission_percent: percent,
          referral_code: profile.referral_code,
          payout_mode: profile.payout_mode,
          net_amount_cents: net_cents
        }
      )
    end

    def net_amount_for(charge)
      return [nil, nil] if charge.processor_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      stripe_charge = Stripe::Charge.retrieve(charge.processor_id)
      balance_tx_id = stripe_charge.balance_transaction
      if balance_tx_id.present?
        tx = Stripe::BalanceTransaction.retrieve(balance_tx_id)
        return [tx.net.to_i, tx.currency] if tx&.net
      end

      fallback_amount = charge.amount.to_i - charge.application_fee_amount.to_i
      [fallback_amount, charge.currency]
    rescue StandardError => e
      logger.warn("[Partners::CommissionBuilder] stripe net lookup failed charge_id=#{charge.id} processor_id=#{charge.processor_id}: #{e.class} - #{e.message}")
      fallback_amount = charge.amount.to_i - charge.application_fee_amount.to_i
      [fallback_amount, charge.currency]
    end
  end
end
