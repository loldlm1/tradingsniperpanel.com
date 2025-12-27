module Billing
  class InvoicePlanLabeler
    def initialize(pricing_catalog: nil, logger: Rails.logger)
      @pricing_catalog = pricing_catalog
      @logger = logger
    end

    def label_for(invoice, fallback_label: nil)
      price_totals = price_totals_for(invoice)
      if price_totals.blank? && stripe_enabled?
        stripe_invoice = fetch_stripe_invoice(stripe_invoice_id(invoice))
        price_totals = price_totals_for(stripe_invoice) if stripe_invoice.present?
      end

      return fallback_label if price_totals.blank?

      if price_totals.size == 1
        price_key = price_totals.keys.first
        return plan_label_for(price_key) || fallback_label
      end

      from_key, to_key = select_change_keys(price_totals)
      return fallback_label if from_key.blank? || to_key.blank?

      change_label = change_label_for(from_key, to_key)
      I18n.t(
        "dashboard.billing.invoice_plan_change",
        from: plan_label_for(from_key),
        to: plan_label_for(to_key),
        change: change_label
      )
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] failed invoice_id=#{invoice_id(invoice)}: #{e.class} - #{e.message}")
      fallback_label
    end

    private

    attr_reader :pricing_catalog, :logger

    def price_totals_for(invoice)
      lines = invoice_lines(invoice)
      return {} if lines.blank?

      totals = Hash.new(0)
      lines.each do |line|
        price_key = price_key_for_line(line)
        next if price_key.blank?

        totals[price_key] += line_amount(line)
      end

      totals.compact_blank
    end

    def invoice_lines(invoice)
      invoice_object = stripe_invoice_object(invoice)
      return [] if invoice_object.blank?

      lines = if invoice_object.respond_to?(:lines)
                invoice_object.lines
              elsif invoice_object.is_a?(Hash)
                invoice_object["lines"] || invoice_object[:lines]
              end

      return [] if lines.blank?

      if lines.respond_to?(:data)
        Array(lines.data)
      elsif lines.is_a?(Hash)
        Array(lines["data"] || lines[:data])
      else
        Array(lines)
      end
    end

    def stripe_invoice_object(invoice)
      return invoice if stripe_invoice?(invoice)

      if invoice.respond_to?(:stripe_invoice) && invoice.stripe_invoice.present?
        return invoice.stripe_invoice
      end

      data = invoice.respond_to?(:data) ? invoice.data : nil
      data&.dig("stripe_invoice") || data&.dig(:stripe_invoice)
    end

    def price_key_for_line(line)
      price_id, product_id = pricing_details_for_line(line)
      price_key = price_key_from_ids(price_id, product_id)
      return price_key if price_key.present?

      price = line_price_object(line)
      price_id = price_id_for(price) || plan_id_for(line)
      product_id = product_id_for(price) || plan_product_id_for(line)

      price_key_from_ids(price_id, product_id)
    end

    def pricing_details_for_line(line)
      pricing = line_pricing(line)
      return [nil, nil] if pricing.blank?

      pricing_type = value_for(pricing, :type)
      if pricing_type.present? && pricing_type.to_s != "price_details"
        return [nil, nil]
      end

      details = value_for(pricing, :price_details)
      price_id = extract_id(value_for(details, :price))
      product_id = extract_id(value_for(details, :product))
      [price_id, product_id]
    end

    def line_pricing(line)
      value_for(line, :pricing)
    end

    def line_price_object(line)
      value_for(line, :price)
    end

    def price_id_for(price)
      extract_id(price)
    end

    def product_id_for(price)
      product = value_for(price, :product)
      extract_id(product)
    end

    def plan_id_for(line)
      extract_id(value_for(line, :plan))
    end

    def plan_product_id_for(line)
      plan = value_for(line, :plan)
      product = value_for(plan, :product)
      extract_id(product)
    end

    def price_key_from_ids(price_id, product_id)
      price_key = Billing::PriceKeyResolver.key_for_product_id(product_id)
      price_key ||= Billing::PriceKeyResolver.key_for_price_id(price_id)
      price_key
    end

    def line_amount(line)
      amount = value_for(line, :amount)
      amount = value_for(line, :subtotal) if amount.nil?
      amount.to_i
    end

    def select_change_keys(price_totals)
      sorted = price_totals.sort_by { |_, amount| amount.to_i }
      [sorted.first[0], sorted.last[0]]
    end

    def change_label_for(from_key, to_key)
      change = plan_comparator.compare(current_key: from_key, target_key: to_key)
      key = change == :downgrade ? "dashboard.billing.invoice_change_downgrade" : "dashboard.billing.invoice_change_upgrade"
      I18n.t(key)
    end

    def plan_comparator
      @plan_comparator ||= Billing::PlanComparator.new(pricing_catalog: pricing_catalog, stripe_fallback: false)
    end

    def plan_label_for(price_key)
      tier, interval = parse_price_key(price_key)
      return if tier.blank?

      tier_label = I18n.t("dashboard.plans.tiers.#{tier}.name", default: tier.to_s.humanize)
      interval_key = interval.to_s == "annual" ? "annually" : interval
      interval_label = if interval_key.present?
                         I18n.t("dashboard.plans.toggle.#{interval_key}", default: interval.to_s.humanize)
                       end

      if interval_label.present?
        I18n.t("dashboard.plan_card.plan_label", tier: tier_label, interval: interval_label)
      else
        I18n.t("dashboard.plan_card.plan_label_tier_only", tier: tier_label)
      end
    end

    def parse_price_key(price_key)
      parts = price_key.to_s.split("_")
      return [nil, nil] if parts.size < 2

      [parts.first.to_sym, parts.last]
    end

    def invoice_id(invoice)
      invoice.respond_to?(:id) ? invoice.id : nil
    end

    def stripe_invoice?(invoice)
      invoice.respond_to?(:lines)
    end

    def stripe_invoice_id(invoice)
      return invoice.id if stripe_invoice?(invoice)

      data = invoice.respond_to?(:data) ? invoice.data : nil
      stripe_invoice = data&.dig("stripe_invoice") || data&.dig(:stripe_invoice)
      extract_id(stripe_invoice)
    end

    def fetch_stripe_invoice(stripe_invoice_id)
      return if stripe_invoice_id.blank?

      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Invoice.retrieve(
        {
          id: stripe_invoice_id,
          expand: ["lines.data.pricing.price_details", "lines.data.plan.product", "lines.data.price.product"]
        }
      )
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] stripe fetch failed invoice_id=#{stripe_invoice_id}: #{e.class} - #{e.message}")
      nil
    end

    def stripe_enabled?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def value_for(source, key)
      return if source.blank?

      if source.respond_to?(key)
        source.public_send(key)
      elsif source.is_a?(Hash)
        source[key.to_s] || source[key.to_sym]
      end
    end

    def extract_id(value)
      return if value.blank?

      if value.respond_to?(:id)
        value.id
      elsif value.is_a?(Hash)
        value["id"] || value[:id]
      else
        value
      end
    end
  end
end
