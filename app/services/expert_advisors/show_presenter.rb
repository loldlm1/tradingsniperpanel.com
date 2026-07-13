require "set"

module ExpertAdvisors
  class ShowPresenter
    include Rails.application.routes.url_helpers

    AddonItem = Struct.new(:title, :owned, :purchase_url, :guide_url, keyword_init: true)

    RANGE_DAYS = 30
    MAIN_LINE_COLOR = "#8470FF"
    BALANCE_PIE_PALETTE = [
      { color: "#4BD37D" },
      { color: "#F7CD4C" },
      { color: "#7BC8FF" },
      { color: "#8470FF" }
    ].freeze

    def initialize(user:, expert_advisor:, entry:, locale: I18n.locale, marketplace_available: false, now: Time.current)
      @user = user
      @expert_advisor = expert_advisor
      @entry = entry
      @locale = locale.presence || I18n.locale
      @marketplace_available = marketplace_available
      @now = now

      preload_context
    end

    attr_reader :expert_advisor, :entry, :locale

    def default_url_options
      { locale: locale }
    end

    def status
      entry&.status || :locked
    end

    def accessible?
      entry&.accessible
    end

    def system_status_label
      I18n.t("dashboard.expert_advisors.show.system_status.#{status}", default: status.to_s.humanize)
    end

    def status_badge_class
      case status.to_s
      when "active"
        "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-200"
      when "trial"
        "bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-200"
      when "expired", "revoked"
        "bg-rose-100 text-rose-700 dark:bg-rose-500/20 dark:text-rose-200"
      else
        "bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-200"
      end
    end

    def license_status_label
      I18n.t("dashboard.expert_advisors.status.#{status}", default: status.to_s.humanize)
    end

    def type_label
      I18n.t("dashboard.expert_advisors.types.#{expert_advisor.ea_type}", default: expert_advisor.ea_type.to_s.humanize)
    end

    def description
      expert_advisor.description.presence
    end

    def system_details
      [
        detail_row("allowed_tiers", allowed_tiers_label),
        detail_row("trial_enabled", boolean_label(expert_advisor.trial_enabled?)),
        detail_row("guide_en", availability_label(expert_advisor.doc_guide_en.present?)),
        detail_row("guide_es", availability_label(expert_advisor.doc_guide_es.present?)),
        detail_row("ea_file", bundle_status_label),
        detail_row("last_sync", last_sync_label),
        detail_row("broker_accounts", broker_accounts_label)
      ]
    end

    def guide_preview
      @guide_preview ||= ExpertAdvisors::GuidePreview.call(expert_advisor.doc_guide_for(locale))
    end

    def guide_heading
      nil
    end

    def guide_copy
      I18n.t("dashboard.expert_advisors.show.guide_copy")
    end

    def guide_url
      dashboard_expert_advisor_guides_path(expert_advisor, locale: locale)
    end

    def download_url
      return nil unless download_enabled?

      dashboard_expert_advisor_download_path(expert_advisor, locale: locale)
    end

    def download_enabled?
      accessible? && download_available?
    end

    def download_available?
      expert_advisor.ea_files.attached? || expert_advisor.expert_advisor_bundles.any?
    end

    def unlock_url
      @unlock_url ||= begin
        if marketplace_available
          product = MarketplaceProduct.active
                                       .joins(billing_plan: :billing_plan_entitlements)
                                       .where(billing_plan_entitlements: { expert_advisor_id: expert_advisor.id })
                                       .order(:sort_order)
                                       .first
          return dashboard_marketplace_product_path(product, locale: locale) if product.present?
        end

        tier = allowed_tiers.first
        return dashboard_plans_path(locale: locale) if tier.blank?

        price_key = BillingPlan.purchasable.where(tier: tier).order(:sort_order).pick(:key)
        return dashboard_plans_path(locale: locale) if price_key.blank?

        dashboard_plans_path(locale: locale, price_key: price_key)
      end
    end

    def license_key
      entry&.license_key
    end

    def license_key_display
      return license_key if license_key.present?

      I18n.t("dashboard.expert_advisors.license.locked_value")
    end

    def license_copy_enabled?
      license_key.present?
    end

    def license_token_metadata_label
      return if license.blank? || license_key.blank?

      if license.token_rotated_at.present?
        I18n.t(
          "dashboard.expert_advisors.show.token_metadata_rotated",
          version: license.token_version,
          date: I18n.l(license.token_rotated_at, format: :short_with_year, locale: locale),
          locale: locale
        )
      else
        I18n.t(
          "dashboard.expert_advisors.show.token_metadata",
          version: license.token_version,
          locale: locale
        )
      end
    end

    def license_expires_label
      expires_at = license_expires_at
      return nil if expires_at.blank?

      date_label = I18n.l(expires_at, format: :short_with_year)
      if status.to_s == "trial"
        I18n.t("dashboard.expert_advisors.show.trial_ends", date: date_label)
      else
        I18n.t("dashboard.expert_advisors.show.expires_on", date: date_label)
      end
    end

    def last_sync_label
      synced_at = license&.last_synced_at
      return I18n.t("dashboard.expert_advisors.show.values.not_synced") if synced_at.blank?

      I18n.l(synced_at, format: :short_with_year)
    end

    def broker_accounts
      @broker_accounts ||= license&.broker_accounts.to_a
    end

    def latest_broker_account
      return nil if license.blank?

      latest_result = results_scope.includes(:broker_account).order(result_timestamp: :desc).limit(1).first
      return latest_result.broker_account if latest_result&.broker_account.present?

      broker_accounts.max_by { |account| account.updated_at || account.created_at }
    end

    def broker_accounts_label
      I18n.t("dashboard.expert_advisors.show.values.broker_accounts_count", count: broker_accounts.size)
    end

    def pnl_summary
      {
        total: currency(pnl_30_days_total),
        average: currency(pnl_30_days_average),
        chart: pnl_chart
      }
    end

    def balance_summary
      {
        total: currency(pnl_30_days_total),
        chart: balance_chart
      }
    end

    def addons_summary
      {
        total_count: addons_total_count,
        owned_count: addons_owned_count,
        progress_percent: addons_progress_percent,
        items: addon_items
      }
    end

    private

    attr_reader :user, :marketplace_available, :now

    def preload_context
      @addons = load_addons
      @purchased_plan_ids = load_purchased_plan_ids
    end

    def detail_row(key, value)
      { label: I18n.t("dashboard.expert_advisors.show.details.#{key}"), value: value }
    end

    def allowed_tiers
      tiers = entry&.allowed_tiers.presence || expert_advisor.subscription_tiers
      tiers.presence || BillingPlan.subscription_tiers.map(&:tier)
    end

    def allowed_tiers_label
      tiers = Array(allowed_tiers).map(&:to_s).reject(&:blank?)
      return I18n.t("dashboard.expert_advisors.detail_tier_all") if tiers.empty?

      tiers.join(", ")
    end

    def availability_label(available)
      key = available ? "available" : "unavailable"
      I18n.t("dashboard.expert_advisors.show.values.#{key}")
    end

    def boolean_label(value)
      key = value ? "yes" : "no"
      I18n.t("dashboard.expert_advisors.show.values.#{key}")
    end

    def bundle_status_label
      if expert_advisor.expert_advisor_bundles.active.exists?
        I18n.t("dashboard.expert_advisors.show.values.bundle_active")
      elsif expert_advisor.ea_files.attached?
        I18n.t("dashboard.expert_advisors.show.values.file_available")
      else
        I18n.t("dashboard.expert_advisors.show.values.file_missing")
      end
    end

    def license
      @license ||= entry&.license || user&.licenses&.find_by(expert_advisor_id: expert_advisor.id)
    end

    def license_expires_at
      return nil if license.blank?
      return license.trial_ends_at if status.to_s == "trial"

      license.key_expires_at || entry&.expires_at
    end

    def date_range
      @date_range ||= (from_date..to_date).to_a
    end

    def chart_labels
      @chart_labels ||= date_range.map { |date| date.strftime("%Y-%m-%d") }
    end

    def from_date
      @from_date ||= to_date - (RANGE_DAYS - 1)
    end

    def to_date
      @to_date ||= now.utc.to_date
    end

    def from_ts
      @from_ts ||= Time.utc(from_date.year, from_date.month, from_date.day).to_i
    end

    def to_ts
      @to_ts ||= Time.utc(to_date.year, to_date.month, to_date.day, 23, 59, 59).to_i
    end

    def results_scope
      @results_scope ||= BrokerAccountDailyResult
                        .joins(broker_account: { license: :expert_advisor })
                        .where(licenses: { user_id: user.id, expert_advisor_id: expert_advisor.id })
    end

    def range_results
      @range_results ||= results_scope.in_range(from_ts, to_ts)
    end

    def pnl_30_days_total
      @pnl_30_days_total ||= range_results.sum(:result_value) || BigDecimal("0")
    end

    def pnl_30_days_average
      days = date_range.size
      return BigDecimal("0") if days.zero?

      pnl_30_days_total / days
    end

    def pnl_chart
      daily_totals = range_results
                     .group("date_trunc('day', to_timestamp(broker_account_daily_results.result_timestamp) AT TIME ZONE 'UTC')")
                     .sum(:result_value)
                     .transform_keys { |ts| ts.to_date }
      data = date_range.map { |date| (daily_totals[date] || 0).to_f }
      return nil if data.all?(&:zero?)

      {
        labels: chart_labels,
        datasets: [
          {
            label: expert_advisor.name,
            data: data,
            color: MAIN_LINE_COLOR
          }
        ]
      }
    end

    def balance_chart
      totals = range_results.group("broker_accounts.company").sum(:result_value)
      sorted = totals.sort_by { |_, value| -value.to_f.abs }
      return nil if sorted.empty?

      top = sorted.first(5)
      remainder = sorted.drop(5)
      if remainder.any?
        other_total = remainder.sum { |(_, value)| value.to_f }
        top << [ I18n.t("dashboard.expert_advisors.show.values.other", default: "Other"), other_total ]
      end

      labels = []
      data = []
      colors = []

      top.each_with_index do |(company, total), idx|
        palette = BALANCE_PIE_PALETTE[idx % BALANCE_PIE_PALETTE.size]
        labels << company
        data << total.to_f.abs
        colors << palette[:color]
      end

      {
        labels: labels,
        datasets: [
          {
            data: data,
            colors: colors
          }
        ]
      }
    end

    def load_addons
      Addon.where(addonable: expert_advisor)
           .includes(:billing_plan, :marketplace_product)
           .left_joins(billing_plan: :marketplace_product)
           .order(Arel.sql("marketplace_products.sort_order ASC NULLS LAST, marketplace_products.title_en ASC NULLS LAST"))
    end

    def load_purchased_plan_ids
      return Set.new if user.blank?

      plan_ids = @addons.map(&:billing_plan_id).compact.uniq
      return Set.new if plan_ids.empty?

      MarketplacePurchase.where(user: user, billing_plan_id: plan_ids).pluck(:billing_plan_id).to_set
    end

    def addon_items
      addons = displayed_addons
      return [] if addons.empty?

      owned, unowned = addons.partition { |addon| purchased?(addon) }
      ordered = owned + unowned

      ordered.map do |addon|
        AddonItem.new(
          title: addon_title(addon),
          owned: purchased?(addon),
          purchase_url: addon_purchase_url(addon),
          guide_url: addon_guide_url(addon)
        )
      end
    end

    def addons_total_count
      displayed_addons.size
    end

    def addons_owned_count
      displayed_addons.count { |addon| purchased?(addon) }
    end

    def addons_progress_percent
      total = addons_total_count
      return 0 if total.zero?

      ((addons_owned_count.to_f / total) * 100).round
    end

    def purchased?(addon)
      @purchased_plan_ids.include?(addon.billing_plan_id)
    end

    def displayed_addons
      @displayed_addons ||= marketplace_available ? Array(@addons) : Array(@addons).select { |addon| purchased?(addon) }
    end

    def addon_title(addon)
      product = addon.marketplace_product
      product ? product.title_for(locale) : addon.key
    end

    def addon_purchase_url(addon)
      return nil unless marketplace_available

      product = addon.marketplace_product
      return nil if product.blank?

      dashboard_marketplace_product_path(product, locale: locale)
    end

    def addon_guide_url(addon)
      return nil unless purchased?(addon)
      return nil unless accessible?

      dashboard_expert_advisor_addon_guide_path(expert_advisor, addon_key: addon.key, locale: locale)
    end

    def currency(amount)
      ActionController::Base.helpers.number_to_currency((amount || 0).to_f, unit: "$", precision: 2)
    end
  end
end
