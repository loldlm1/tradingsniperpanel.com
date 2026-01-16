module Admin
  module Analytics
    class RevenueMetrics
      Result = Struct.new(
        :stripe_gross_cents,
        :stripe_refunds_cents,
        :stripe_net_cents,
        :manual_gross_cents,
        :gross_cents,
        :partner_commissions_cents,
        :net_cents,
        :marketplace_purchases_count,
        :unique_buyers_count,
        :subscribed_users_count,
        keyword_init: true
      )

      def initialize(starts_at:, ends_at:)
        @starts_at = starts_at
        @ends_at = ends_at
      end

      def call
        stripe_gross = stripe_charges.sum(:amount)
        stripe_refunds = stripe_charges.sum(:amount_refunded)
        stripe_net = stripe_gross - stripe_refunds

        manual_gross = manual_transactions.sum(:amount_cents) + manual_subscriptions.sum(:amount_cents)
        gross = stripe_gross + manual_gross

        partner_commissions = partner_commissions_scope.sum(:amount_cents)
        net = gross - stripe_refunds - partner_commissions

        purchases_scope = MarketplacePurchase.where(purchased_at: range)

        Result.new(
          stripe_gross_cents: stripe_gross,
          stripe_refunds_cents: stripe_refunds,
          stripe_net_cents: stripe_net,
          manual_gross_cents: manual_gross,
          gross_cents: gross,
          partner_commissions_cents: partner_commissions,
          net_cents: net,
          marketplace_purchases_count: purchases_scope.count,
          unique_buyers_count: purchases_scope.distinct.count(:user_id),
          subscribed_users_count: subscribed_users_count
        )
      end

      private

      attr_reader :starts_at, :ends_at

      def range
        starts_at..ends_at
      end

      def stripe_charges
        return Pay::Charge.none unless Pay::Charge.table_exists?

        scope = Pay::Charge.where(created_at: range)
        status_expr = "COALESCE(pay_charges.data->>'status', pay_charges.object->>'status')"
        scope.where("#{status_expr} IS NULL OR #{status_expr} = ?", "succeeded")
      end

      def manual_transactions
        return ManualTransaction.none unless ManualTransaction.table_exists?

        ManualTransaction.where(paid_at: range)
      end

      def manual_subscriptions
        return ManualSubscription.none unless ManualSubscription.table_exists?

        ManualSubscription.where(paid_at: range)
      end

      def partner_commissions_scope
        return PartnerCommission.none unless PartnerCommission.table_exists?

        PartnerCommission.where(status: %i[pending requested paid], occurred_at: range)
      end

      def subscribed_users_count
        stripe_ids = stripe_subscription_user_ids
        manual_ids = manual_subscription_user_ids

        User.where(id: stripe_ids).or(User.where(id: manual_ids)).distinct.count(:id)
      end

      def stripe_subscription_user_ids
        return User.none unless Pay::Subscription.table_exists?

        Pay::Subscription.joins(:customer)
                         .where(status: %w[active trialing])
                         .where("pay_subscriptions.current_period_end IS NULL OR pay_subscriptions.current_period_end >= ?", ends_at)
                         .where("pay_subscriptions.ends_at IS NULL OR pay_subscriptions.ends_at >= ?", ends_at)
                         .select("pay_customers.owner_id")
      end

      def manual_subscription_user_ids
        return User.none unless ManualSubscription.table_exists?

        ManualSubscription.active_at(ends_at).select(:user_id)
      end
    end
  end
end
