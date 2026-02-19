module Billing
  class StripeInvoiceNotificationProcessor
    SUBSCRIPTION_CREATE_REASON = "subscription_create".freeze
    SUBSCRIPTION_UPDATE_REASON = "subscription_update".freeze
    SUBSCRIPTION_CYCLE_REASON = "subscription_cycle".freeze

    def initialize(event:, logger: Rails.logger)
      @event = event
      @logger = logger
    end

    def call
      return unless event_type.in?(%w[invoice.payment_succeeded invoice.payment_failed])

      invoice = event.data.object
      return unless invoice.respond_to?(:id)
      return if invoice.id.blank?

      if event_type == "invoice.payment_succeeded"
        process_succeeded_invoice(invoice)
      else
        process_failed_invoice(invoice)
      end
    rescue StandardError => e
      logger.error("[Billing::StripeInvoiceNotificationProcessor] failed event_id=#{event_id} event_type=#{event_type}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :event, :logger

    def process_succeeded_invoice(invoice)
      return unless invoice.amount_paid.to_i.positive?

      case invoice.billing_reason.to_s
      when SUBSCRIPTION_CREATE_REASON
        deliver_subscription_started(invoice)
      when SUBSCRIPTION_UPDATE_REASON
        deliver_subscription_upgraded(invoice)
      end
    end

    def process_failed_invoice(invoice)
      return unless invoice.billing_reason.to_s == SUBSCRIPTION_CYCLE_REASON
      return unless invoice.amount_due.to_i.positive?

      delivery_context = build_delivery_context(invoice)
      return unless delivery_context

      return unless track_delivery_once(
        event_key: "subscription_renewal_payment_failed:#{invoice.id}",
        event_type: "subscription_renewal_payment_failed",
        invoice: invoice,
        context: delivery_context
      )

      with_user_locale(delivery_context[:user]) do
        BillingNotificationsMailer.with(
          user: delivery_context[:user],
          plan_name: delivery_context[:plan_name],
          amount_cents: invoice.amount_due.to_i,
          currency: invoice.currency,
          invoice_id: invoice.id,
          invoice_url: invoice.hosted_invoice_url
        ).subscription_renewal_payment_failed.deliver_later
      end
    end

    def deliver_subscription_started(invoice)
      delivery_context = build_delivery_context(invoice)
      return unless delivery_context

      return unless track_delivery_once(
        event_key: "subscription_started:#{invoice.id}",
        event_type: "subscription_started",
        invoice: invoice,
        context: delivery_context
      )

      with_user_locale(delivery_context[:user]) do
        BillingNotificationsMailer.with(
          user: delivery_context[:user],
          plan_name: delivery_context[:plan_name],
          amount_cents: invoice.amount_paid.to_i,
          currency: invoice.currency,
          invoice_id: invoice.id,
          invoice_url: invoice.hosted_invoice_url
        ).subscription_started.deliver_later
      end
    end

    def deliver_subscription_upgraded(invoice)
      delivery_context = build_delivery_context(invoice)
      return unless delivery_context

      return unless track_delivery_once(
        event_key: "subscription_upgraded:#{invoice.id}",
        event_type: "subscription_upgraded",
        invoice: invoice,
        context: delivery_context
      )

      with_user_locale(delivery_context[:user]) do
        BillingNotificationsMailer.with(
          user: delivery_context[:user],
          plan_name: delivery_context[:plan_name],
          amount_cents: invoice.amount_paid.to_i,
          currency: invoice.currency,
          invoice_id: invoice.id,
          invoice_url: invoice.hosted_invoice_url
        ).subscription_upgraded.deliver_later
      end
    end

    def build_delivery_context(invoice)
      pay_customer = find_pay_customer(invoice)
      user = pay_customer&.owner
      return unless user.is_a?(User)

      pay_subscription = find_pay_subscription(invoice, pay_customer: pay_customer)
      {
        user: user,
        pay_customer: pay_customer,
        pay_subscription: pay_subscription,
        plan_name: resolve_plan_name(invoice, pay_subscription: pay_subscription)
      }
    end

    def track_delivery_once(event_key:, event_type:, invoice:, context:)
      saved = Billing::EmailDeliveryTracker.record_once(
        event_key: event_key,
        event_type: event_type,
        user_id: context[:user].id,
        pay_subscription_id: context[:pay_subscription]&.id,
        invoice_id: invoice.id,
        metadata: {
          stripe_event_id: event_id,
          billing_reason: invoice.billing_reason,
          amount_paid: invoice.amount_paid,
          amount_due: invoice.amount_due
        }.compact
      )

      unless saved
        logger.info("[Billing::StripeInvoiceNotificationProcessor] skipped duplicate event_key=#{event_key} invoice_id=#{invoice.id}")
      end

      saved
    end

    def find_pay_customer(invoice)
      customer_id = invoice.customer.to_s
      return if customer_id.blank?

      Pay::Customer.find_by(processor: :stripe, processor_id: customer_id)
    end

    def find_pay_subscription(invoice, pay_customer:)
      subscription_processor_id = invoice_hash(invoice).dig("parent", "subscription_details", "subscription")
      subscription_processor_id = invoice_hash(invoice)["subscription"] if subscription_processor_id.blank?
      return if subscription_processor_id.blank?

      scope = pay_customer ? pay_customer.subscriptions : Pay::Subscription
      scope.find_by(processor_id: subscription_processor_id)
    end

    def resolve_plan_name(invoice, pay_subscription:)
      price_ids = extract_price_ids(invoice)
      price_ids << pay_subscription.processor_plan if pay_subscription&.processor_plan.present?

      price_ids.uniq.each do |price_id|
        plan = BillingPlan.for_price_id(price_id)
        return plan.name if plan
      end

      nil
    end

    def extract_price_ids(invoice)
      lines = Array(invoice_hash(invoice).dig("lines", "data"))
      positive_lines, remaining_lines = lines.partition { |line| line["amount"].to_i.positive? }

      (positive_lines + remaining_lines).filter_map do |line|
        line.dig("pricing", "price_details", "price").presence ||
          line.dig("price", "id").presence ||
          (line["price"] if line["price"].is_a?(String))
      end
    end

    def invoice_hash(invoice)
      @invoice_hash ||= {}
      @invoice_hash[invoice.id] ||= invoice.respond_to?(:to_hash) ? invoice.to_hash : {}
    end

    def with_user_locale(user)
      locale = user.preferred_locale_code
      locale = I18n.default_locale if locale.blank?

      I18n.with_locale(locale) { yield }
    end

    def event_type
      event&.type.to_s
    end

    def event_id
      event&.id.to_s.presence
    end
  end
end
