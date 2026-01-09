module Billing
  class IntervalLabeler
    INTERVAL_ORDER = {
      "day" => 1,
      "week" => 2,
      "month" => 3,
      "year" => 4
    }.freeze

    def self.interval_key(interval:, interval_count:)
      return nil if interval.blank?

      count = interval_count.to_i
      return interval.to_s if count <= 0

      if count == 1
        return "monthly" if interval.to_s == "month"
        return "annual" if interval.to_s == "year"
        return "weekly" if interval.to_s == "week"
        return "daily" if interval.to_s == "day"
      end

      "#{count}_#{interval}"
    end

    def self.label(interval:, interval_count:)
      return nil if interval.blank?

      count = interval_count.to_i
      return legacy_label(interval) if count == 1

      I18n.t("dashboard.plans.interval.toggle.#{interval}", count: count, default: default_every_label(interval, count))
    end

    def self.billed_label(interval:, interval_count:)
      return nil if interval.blank?

      count = interval_count.to_i
      return legacy_billed_label(interval) if count == 1

      I18n.t("dashboard.plans.interval.billed.#{interval}", count: count, default: default_billed_label(interval, count))
    end

    def self.per_label(interval:, interval_count:)
      return nil if interval.blank?

      count = interval_count.to_i
      unit = I18n.t("dashboard.plans.interval.short_unit.#{interval}", count: count, default: interval.to_s)
      I18n.t("dashboard.plans.interval.per_label", count: count, unit: unit, default: default_per_label(unit, count))
    end

    def self.sort_key(interval:, interval_count:)
      return [0, 0] if interval.blank?

      count = interval_count.to_i
      order = INTERVAL_ORDER.fetch(interval.to_s, 99)
      [order, count.positive? ? count : 1]
    end

    def self.legacy_key(interval)
      case interval.to_s
      when "year" then "annually"
      when "annual" then "annually"
      when "month" then "monthly"
      when "monthly" then "monthly"
      when "week" then "weekly"
      when "weekly" then "weekly"
      when "day" then "daily"
      when "daily" then "daily"
      else interval.to_s
      end
    end

    def self.legacy_label(interval)
      key = legacy_key(interval)
      I18n.t("dashboard.plans.toggle.#{key}", default: interval.to_s.humanize)
    end

    def self.legacy_billed_label(interval)
      if interval.to_s == "year"
        return I18n.t("dashboard.plans.toggle.billed_annually", default: "Billed annually")
      end

      I18n.t("dashboard.plans.interval.billed.#{interval}", count: 1, default: "Billed #{interval}")
    end

    def self.default_every_label(interval, count)
      unit = interval.to_s.humanize.downcase
      "Every #{count} #{unit}"
    end

    def self.default_billed_label(interval, count)
      unit = interval.to_s.humanize.downcase
      "Billed every #{count} #{unit}"
    end

    def self.default_per_label(unit, count)
      return "/#{unit}" if count == 1

      "/#{count} #{unit}"
    end
  end
end
