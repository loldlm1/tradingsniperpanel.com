module Billing
  class InvoicePlanLabeler
    def initialize(pricing_catalog: nil, logger: Rails.logger)
      @pricing_catalog = pricing_catalog
      @logger = logger
    end

    def label_for(invoice, fallback_label: nil)
      cached = cached_plan_keys(invoice)
      label = label_from_keys(cached)
      return label if label.present?

      keys = plan_keys_from_invoice(invoice)
      label = label_from_keys(keys)
      if label.present?
        cache_plan_keys(invoice, keys)
        return label
      end

      keys = plan_keys_from_stripe(invoice)
      label = label_from_keys(keys)
      if label.present?
        cache_plan_keys(invoice, keys)
        return label
      end

      fallback_label
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] failed invoice_id=#{invoice_id(invoice)}: #{e.class} - #{e.message}")
      fallback_label
    end

    private

    attr_reader :pricing_catalog, :logger

    def plan_keys_from_invoice(invoice)
      lines = invoice_lines(invoice)
      return {} if lines.blank?

      totals = Hash.new(0)
      lines.each do |line|
        price_key = price_key_for_line(line)
        next if price_key.blank?

        totals[price_key] += line_amount(line)
      end

      build_plan_keys(totals.compact_blank)
    end

    def plan_keys_from_stripe(invoice)
      return {} unless stripe_enabled?

      stripe_invoice_id = stripe_invoice_id(invoice)
      return {} if stripe_invoice_id.blank?

      stripe_invoice = fetch_stripe_invoice(stripe_invoice_id)
      return {} if stripe_invoice.blank?

      lines = invoice_lines(stripe_invoice)
      return {} if lines.blank?

      totals = Hash.new(0)
      lines.each do |line|
        price_key = price_key_for_line(line)
        next if price_key.blank?

        totals[price_key] += line_amount(line)
      end

      keys = build_plan_keys(totals.compact_blank)
      cache_stripe_invoice(invoice, stripe_invoice)
      keys
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
      price = line_price_object(line)
      price_id = price_id_for(price)
      product_id = product_id_for(price)
      price_id ||= plan_id_for(line)
      product_id ||= plan_product_id_for(line)

      price_key = Billing::PriceKeyResolver.key_for_product_id(product_id)
      price_key ||= Billing::PriceKeyResolver.key_for_price_id(price_id)
      price_key
    end

    def line_price_object(line)
      if line.respond_to?(:price)
        line.price
      elsif line.is_a?(Hash)
        line["price"] || line[:price]
      end
    end

    def price_id_for(price)
      return if price.blank?

      if price.respond_to?(:id)
        price.id
      elsif price.is_a?(Hash)
        price["id"] || price[:id]
      else
        price
      end
    end

    def product_id_for(price)
      return if price.blank?

      product = if price.respond_to?(:product)
                  price.product
                elsif price.is_a?(Hash)
                  price["product"] || price[:product]
                end

      extract_id(product)
    end

    def plan_id_for(line)
      plan = if line.respond_to?(:plan)
               line.plan
             elsif line.is_a?(Hash)
               line["plan"] || line[:plan]
             end

      return if plan.blank?

      if plan.respond_to?(:id)
        plan.id
      elsif plan.is_a?(Hash)
        plan["id"] || plan[:id]
      else
        plan
      end
    end

    def plan_product_id_for(line)
      plan = if line.respond_to?(:plan)
               line.plan
             elsif line.is_a?(Hash)
               line["plan"] || line[:plan]
             end

      return if plan.blank?

      product = if plan.respond_to?(:product)
                  plan.product
                elsif plan.is_a?(Hash)
                  plan["product"] || plan[:product]
                end

      extract_id(product)
    end

    def line_amount(line)
      amount = if line.respond_to?(:amount)
                 line.amount
               elsif line.is_a?(Hash)
                 line["amount"] || line[:amount]
               end

      amount.to_i
    end

    def build_plan_keys(price_totals)
      return {} if price_totals.blank?

      if price_totals.size == 1
        return { single_key: price_totals.keys.first }
      end

      from_key, to_key = select_change_keys(price_totals)
      return {} if from_key.blank? || to_key.blank?

      { from_key: from_key, to_key: to_key }
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

    def cached_plan_keys(invoice)
      data = invoice.respond_to?(:data) ? invoice.data : nil
      return {} if data.blank?

      if data["invoice_plan_key"].present?
        return { single_key: data["invoice_plan_key"] }
      end

      from_key = data["invoice_plan_from_key"]
      to_key = data["invoice_plan_to_key"]
      return {} if from_key.blank? || to_key.blank?

      { from_key: from_key, to_key: to_key }
    end

    def cache_plan_keys(invoice, keys)
      return unless invoice.respond_to?(:update!)

      data = invoice.respond_to?(:data) ? invoice.data : nil
      data = data.is_a?(Hash) ? data : {}
      update = data.dup

      if keys[:single_key].present?
        update["invoice_plan_key"] = keys[:single_key]
        update.delete("invoice_plan_from_key")
        update.delete("invoice_plan_to_key")
      elsif keys[:from_key].present? && keys[:to_key].present?
        update["invoice_plan_from_key"] = keys[:from_key]
        update["invoice_plan_to_key"] = keys[:to_key]
        update.delete("invoice_plan_key")
      else
        return
      end

      invoice.update!(data: update)
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] cache failed invoice_id=#{invoice_id(invoice)}: #{e.class} - #{e.message}")
    end

    def cache_stripe_invoice(invoice, stripe_invoice)
      return unless invoice.respond_to?(:update!)

      data = invoice.respond_to?(:data) ? invoice.data : nil
      data = data.is_a?(Hash) ? data : {}
      update = data.merge("stripe_invoice" => stripe_invoice.to_hash)
      invoice.update!(data: update)
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] stripe invoice cache failed invoice_id=#{invoice_id(invoice)}: #{e.class} - #{e.message}")
    end

    def label_from_keys(keys)
      return if keys.blank?

      if keys[:single_key].present?
        return plan_label_for(keys[:single_key])
      end

      from_key = keys[:from_key]
      to_key = keys[:to_key]
      return if from_key.blank? || to_key.blank?

      change_label = change_label_for(from_key, to_key)
      I18n.t(
        "dashboard.billing.invoice_plan_change",
        from: plan_label_for(from_key),
        to: plan_label_for(to_key),
        change: change_label
      )
    end

    def stripe_invoice?(invoice)
      invoice.respond_to?(:lines) && invoice.respond_to?(:id)
    end

    def stripe_invoice_id(invoice)
      return invoice.id if stripe_invoice?(invoice)

      data = invoice.respond_to?(:data) ? invoice.data : nil
      return if data.blank?

      stripe_invoice = data["stripe_invoice"] || data[:stripe_invoice]
      return if stripe_invoice.blank?

      if stripe_invoice.respond_to?(:id)
        stripe_invoice.id
      elsif stripe_invoice.is_a?(Hash)
        stripe_invoice["id"] || stripe_invoice[:id]
      end
    end

    def fetch_stripe_invoice(stripe_invoice_id)
      Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"]
      Stripe::Invoice.retrieve(
        {
          id: stripe_invoice_id,
          expand: ["lines.data.price.product", "lines.data.plan.product"]
        }
      )
    rescue StandardError => e
      logger.warn("[Billing::InvoicePlanLabeler] stripe fetch failed invoice_id=#{stripe_invoice_id}: #{e.class} - #{e.message}")
      nil
    end

    def stripe_enabled?
      ENV["STRIPE_PRIVATE_KEY"].present?
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
