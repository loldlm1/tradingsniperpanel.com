module Admin
  module SubscriptionAudits
    class Presenter
      attr_reader :user

      def initialize(user:, context:)
        @user = user
        @context = context
      end

      def customers
        context.customers_by_user.fetch(user.id, [])
      end

      def subscriptions
        context.subscriptions_by_user.fetch(user.id, [])
      end

      def charges
        context.charges_by_user.fetch(user.id, [])
      end

      def manual_grants
        context.manual_grants_by_user.fetch(user.id, [])
      end

      def licenses
        context.licenses_by_user.fetch(user.id, [])
      end

      def current_subscription
        @current_subscription ||= active_stripe_subscription || subscriptions.max_by { |record| sort_time(record) }
      end

      def current_manual_grant
        @current_manual_grant ||= active_manual_grant || manual_grants.max_by { |record| sort_time(record) }
      end

      def access_source
        return "stripe" if active_stripe_subscription
        return "manual" if active_manual_grant
        return "trial" if current_trial_license
        return "superseded" if current_manual_grant&.superseded?
        return "revoked" if licenses.any?(&:revoked?)

        "expired"
      end

      def status
        case access_source
        when "stripe" then active_stripe_subscription.status
        when "manual" then active_manual_grant.status
        when "trial" then current_trial_license.status
        else current_subscription&.status || current_manual_grant&.status || licenses.first&.status
        end
      end

      def plan_name
        current_plan_info&.dig(:plan)&.name || current_manual_grant&.billing_plan&.name
      end

      def processor_plan_reference
        current_plan_info&.dig(:plan)&.key || current_manual_grant&.billing_plan&.key
      end

      def interval
        current_plan_info&.dig(:interval) || current_manual_grant&.billing_plan&.interval || licenses.first&.plan_interval
      end

      def interval_count
        current_plan_info&.dig(:interval_count) || current_manual_grant&.billing_plan&.interval_count
      end

      def interval_label
        return if interval.blank?

        Billing::IntervalLabeler.label(interval: interval, interval_count: interval_count || 1)
      end

      def period_start
        if active_stripe_subscription
          active_stripe_subscription.current_period_start
        elsif active_manual_grant
          active_manual_grant.starts_at
        else
          current_subscription&.current_period_start || current_manual_grant&.starts_at
        end
      end

      def period_end
        if active_stripe_subscription
          active_stripe_subscription.current_period_end || active_stripe_subscription.ends_at
        elsif active_manual_grant
          active_manual_grant.ends_at
        else
          current_subscription&.current_period_end || current_subscription&.ends_at || current_manual_grant&.ends_at
        end
      end

      def cancellation_or_end_at
        current_subscription&.ends_at || current_manual_grant&.superseded_at || current_manual_grant&.ends_at
      end

      def synchronization_at
        candidates = [ current_subscription&.updated_at, licenses.filter_map(&:last_synced_at).max ]
        candidates.compact.max
      end

      def customer_references
        customers.filter_map { |customer| local_customer_reference(customer) }.uniq
      end

      def payment_totals
        currencies = settled_charges.filter_map { |charge| normalize_currency(charge.currency) }
        currencies.concat(manual_grants.filter_map { |grant| normalize_currency(grant.currency) if grant.payment_paid? })

        currencies.uniq.sort.map do |currency|
          currency_charges = settled_charges.select { |charge| normalize_currency(charge.currency) == currency }
          currency_grants = manual_grants.select do |grant|
            grant.payment_paid? && normalize_currency(grant.currency) == currency
          end
          stripe_gross = currency_charges.sum { |charge| charge.amount.to_i }
          refunds = currency_charges.sum { |charge| charge.amount_refunded.to_i }
          manual_paid = currency_grants.sum(&:settled_amount_cents)

          {
            currency: currency,
            stripe_gross_cents: stripe_gross,
            refunds_cents: refunds,
            stripe_net_cents: stripe_gross - refunds,
            manual_paid_cents: manual_paid,
            settled_net_cents: stripe_gross - refunds + manual_paid
          }
        end
      end

      def payment_history
        subscription_references = subscriptions.index_by(&:id).transform_values(&:processor_id)
        charge_rows = charges.map do |charge|
          InvoiceSnapshot.from_charge(
            charge,
            subscription_reference: subscription_references[charge.subscription_id]
          )
        end
        webhook_rows = context.webhooks_by_user.fetch(user.id, []).filter_map do |webhook|
          InvoiceSnapshot.from_webhook(webhook)
        end
        (charge_rows + webhook_rows).sort_by { |row| row.occurred_at || Time.at(0) }.reverse
      end

      def promotion_entries
        subscriptions.filter_map do |subscription|
          metadata = safe_metadata(subscription)
          code = metadata["dashboard_promotion_code"].to_s.presence
          promotion_id = metadata["dashboard_promotion_id"].to_s.presence
          percent = Integer(metadata["dashboard_promotion_percent"], exception: false)
          next if code.blank? && promotion_id.blank? && percent.nil?

          promotion = context.promotion_lookup[promotion_id] || context.promotion_lookup[code]
          {
            subscription_reference: local_subscription_reference(subscription),
            code: code || promotion&.code,
            percent: percent || promotion&.percent_off,
            record_status: promotion_record_status(promotion),
            source: "subscription_metadata"
          }
        end
      end

      def referral_entries
        subscriptions.filter_map do |subscription|
          metadata = safe_metadata(subscription)
          code = metadata["partner_referral_code"].to_s.presence || metadata["referral_code"].to_s.presence
          percent = Integer(metadata["referral_discount_percent"], exception: false)
          next if code.blank? && percent.nil?

          {
            subscription_reference: local_subscription_reference(subscription),
            code: code,
            percent: percent,
            source: "subscription_metadata"
          }
        end
      end

      def referral_relationship
        referral = context.referrals_by_user[user.id]
        return unless referral

        profile = context.partner_profiles_by_user[referral.referrer_id]
        {
          code: referral.referral_code&.code || profile&.referral_code,
          referrer_id: referral.referrer_id,
          discount_percent: profile&.discount_percent_or_default,
          completed_at: referral.completed_at
        }
      end

      def audit_events
        targeted = context.audit_events_by_user.fetch(user.id, [])
        license_ids = licenses.map(&:id)
        global = context.global_audit_events.select do |event|
          affected_ids = Array(event.metadata["affected_license_ids"]).filter_map do |id|
            Integer(id, exception: false)
          end
          (affected_ids & license_ids).any?
        end
        (targeted + global).sort_by { |event| [ event.created_at, event.id ] }.reverse
      end

      def current_plan_info
        @current_plan_info ||= price_info_for(current_subscription)
      end

      def price_info_for(subscription)
        context.price_lookup[subscription&.processor_plan]
      end

      def rotatable_license_count
        licenses.count { |license| license.access_source_subscription? && license.status.in?(%w[active trial]) }
      end

      def manual_access_label
        return unless current_manual_grant

        [ current_manual_grant.status, current_manual_grant.payment_status ].join(" / ")
      end

      def license_status_label
        statuses = licenses.map(&:status).uniq
        statuses.any? ? statuses.join(", ") : nil
      end

      def local_snapshot_warnings
        warnings = []
        warnings << :customer_reference if subscriptions.any? && customer_references.empty?
        warnings << :plan_mapping if current_subscription && current_plan_info.nil?
        warnings << :period_start if current_subscription && current_subscription.current_period_start.nil?
        warnings << :period_end if current_subscription && current_subscription.current_period_end.nil? && current_subscription.ends_at.nil?
        warnings << :invoice_history if current_subscription && context.webhooks_by_user.fetch(user.id, []).empty?
        warnings
      end

      def event_license_ids(event)
        Array(event.metadata["affected_license_ids"]).filter_map { |id| Integer(id, exception: false) }
      end

      def safe_processor_reference(entry)
        record = if entry.source == "pay_charge"
          charges.find { |charge| charge.processor_id == entry.processor_reference }
        else
          context.webhooks_by_user.fetch(user.id, []).find do |webhook|
            object = webhook.event.is_a?(Hash) ? webhook.event.dig("data", "object") : nil
            object.is_a?(Hash) && object["id"].to_s == entry.processor_reference.to_s
          end
        end
        return unless record

        "#{record.class.name}##{record.id}"
      end

      def safe_subscription_reference(entry)
        subscription = subscriptions.find { |record| record.processor_id == entry.subscription_reference }
        local_subscription_reference(subscription)
      end

      private

      attr_reader :context

      def active_stripe_subscription
        @active_stripe_subscription ||= subscriptions.select { |record| active_stripe_record?(record) }
                                                    .max_by { |record| sort_time(record) }
      end

      def active_manual_grant
        @active_manual_grant ||= manual_grants.select { |grant| grant.active_for_time? }
                                                    .max_by { |grant| [ grant.starts_at, grant.id ] }
      end

      def current_trial_license
        licenses.find { |license| license.trial? && license.active_for_request? }
      end

      def settled_charges
        @settled_charges ||= charges.select { |charge| InvoiceSnapshot.from_charge(charge).settled? }
      end

      def safe_metadata(subscription)
        metadata = subscription.metadata if subscription.metadata.is_a?(Hash)
        metadata = subscription.object["metadata"] if metadata.blank? && subscription.object.is_a?(Hash)
        metadata.is_a?(Hash) ? metadata : {}
      end

      def promotion_record_status(promotion)
        return "unavailable" unless promotion
        return "archived" if promotion.archived?
        return "active" if promotion.active_for_checkout?

        "inactive"
      end

      def normalize_currency(value)
        value.to_s.downcase.presence
      end

      def local_customer_reference(customer)
        return unless customer&.id

        "Pay::Customer##{customer.id}"
      end

      def local_subscription_reference(subscription)
        return unless subscription&.id

        "Pay::Subscription##{subscription.id}"
      end

      def active_stripe_record?(subscription)
        return false unless subscription.status.in?(%w[active trialing])
        return false if subscription.ends_at.present? && subscription.ends_at <= Time.current
        return false if subscription.pause_behavior == "void" && subscription.pause_starts_at.present? &&
                        subscription.pause_starts_at <= Time.current

        true
      end

      def sort_time(record)
        record.updated_at || record.created_at || Time.at(0)
      end
    end
  end
end
