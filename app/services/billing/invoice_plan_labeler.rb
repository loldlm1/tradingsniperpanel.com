module Billing
  class InvoicePlanLabeler
    def initialize(pricing_catalog: nil, logger: Rails.logger)
      @pricing_catalog = pricing_catalog
      @logger = logger
    end

    def label_for(invoice, fallback_label: nil)
      price_totals = price_totals_for(invoice)
      return fallback_label if price_totals.blank?

      keys_by_price = price_keys_by_price_id(price_totals.keys)
      return fallback_label if keys_by_price.empty?

      price_totals = price_totals.slice(*keys_by_price.keys)
      return fallback_label if price_totals.blank?

      if keys_by_price.size == 1
        price_key = keys_by_price.values.first
        return plan_label_for(price_key) || fallback_label
      end

      from_price_id, to_price_id = select_change_prices(price_totals)
      from_key = keys_by_price[from_price_id]
      to_key = keys_by_price[to_price_id]
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
        price_id = line_price_id(line)
        next if price_id.blank?

        totals[price_id] += line_amount(line)
      end

      totals.compact_blank
    end

    def invoice_lines(invoice)
      invoice_object = stripe_invoice_for(invoice)
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

    def stripe_invoice_for(invoice)
      if invoice.respond_to?(:stripe_invoice) && invoice.stripe_invoice.present?
        return invoice.stripe_invoice
      end

      data = invoice.respond_to?(:data) ? invoice.data : nil
      data&.dig("stripe_invoice") || data&.dig(:stripe_invoice)
    end

    def line_price_id(line)
      price = if line.respond_to?(:price)
                line.price
              elsif line.is_a?(Hash)
                line["price"] || line[:price]
              end

      price_id = if price.respond_to?(:id)
                   price.id
                 elsif price.is_a?(Hash)
                   price["id"] || price[:id]
                 else
                   price
                 end

      return price_id if price_id.present?

      plan = if line.respond_to?(:plan)
               line.plan
             elsif line.is_a?(Hash)
               line["plan"] || line[:plan]
             end

      if plan.respond_to?(:id)
        plan.id
      elsif plan.is_a?(Hash)
        plan["id"] || plan[:id]
      else
        plan
      end
    end

    def line_amount(line)
      amount = if line.respond_to?(:amount)
                 line.amount
               elsif line.is_a?(Hash)
                 line["amount"] || line[:amount]
               end

      amount.to_i
    end

    def price_keys_by_price_id(price_ids)
      price_ids.each_with_object({}) do |price_id, map|
        price_key = Billing::PriceKeyResolver.key_for_price_id(price_id)
        map[price_id] = price_key if price_key.present?
      end
    end

    def select_change_prices(price_totals)
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
  end
end
