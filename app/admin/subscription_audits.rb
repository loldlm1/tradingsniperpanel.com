ActiveAdmin.register User, as: "SubscriptionAudit" do
  menu label: proc { t("active_admin.subscription_audits.menu") }, priority: 3

  actions :index, :show
  config.batch_actions = false
  config.filters = false
  config.per_page = 25
  config.sort_order = "id_desc"

  controller do
    before_action :require_html_index, only: :index
    helper_method :subscription_audit_presenter

    def scoped_collection
      audit_query.call
    end

    def subscription_audit_presenter(user)
      @subscription_audit_presenters ||= begin
        users = action_name == "index" ? collection.to_a : [ user ]
        audit_query.presenters_for(users)
      end
      @subscription_audit_presenters.fetch(user.id)
    end

    private

    def require_html_index
      head :not_acceptable unless request.format.html?
    end

    def audit_query
      @audit_query ||= Admin::SubscriptionAudits::Query.new(scope: User.all, filters: params)
    end
  end

  member_action :rotate_subscription_licenses, method: :post do
    result = Licenses::RotateTokens.new(
      scope: :user,
      user: resource,
      actor: current_user,
      request_id: params[:request_id]
    ).call
    redirect_to admin_subscription_audit_path(resource),
                notice: t("active_admin.subscription_audits.rotation.user_success", count: result.count)
  rescue Licenses::RotateTokens::Unauthorized
    head :forbidden
  rescue ArgumentError,
         Licenses::RotateTokens::IdempotencyConflict,
         Licenses::RotateTokens::TokenVersionExhausted,
         Licenses::LicenseKeyEncoder::ConfigurationError,
         ActiveRecord::RecordInvalid => e
    redirect_to admin_subscription_audit_path(resource),
                alert: t("active_admin.subscription_audits.rotation.failed", message: e.message)
  end

  collection_action :confirm_rotate_all, method: :get do
    return head :forbidden unless current_user&.master_admin?

    @affected_count = License.active_or_trial.count
    @request_id = SecureRandom.uuid
    @page_title = t("active_admin.subscription_audits.rotation.all_title")
    render "admin/subscription_audits/confirm_rotate_all"
  end

  collection_action :rotate_all, method: :post do
    return head :forbidden unless current_user&.master_admin?

    unless params[:confirmation].to_s == "ROTATE ALL"
      redirect_to confirm_rotate_all_admin_subscription_audits_path,
                  alert: t("active_admin.subscription_audits.rotation.confirmation_invalid")
      return
    end

    result = Licenses::RotateTokens.new(
      scope: :all,
      actor: current_user,
      request_id: params[:request_id]
    ).call
    redirect_to admin_subscription_audits_path,
                notice: t("active_admin.subscription_audits.rotation.all_success", count: result.count)
  rescue Licenses::RotateTokens::Unauthorized
    head :forbidden
  rescue ArgumentError,
         Licenses::RotateTokens::IdempotencyConflict,
         Licenses::RotateTokens::TokenVersionExhausted,
         Licenses::LicenseKeyEncoder::ConfigurationError,
         ActiveRecord::RecordInvalid => e
    redirect_to admin_subscription_audits_path,
                alert: t("active_admin.subscription_audits.rotation.failed", message: e.message)
  end

  action_item :rotate_subscription_licenses, only: :show,
              if: proc { subscription_audit_presenter(resource).rotatable_license_count.positive? } do
    presenter = subscription_audit_presenter(resource)
    link_to t("active_admin.subscription_audits.actions.rotate_user"),
            rotate_subscription_licenses_admin_subscription_audit_path(
              resource,
              request_id: SecureRandom.uuid
            ),
            method: :post,
            data: {
              confirm: t(
                "active_admin.subscription_audits.rotation.user_confirm",
                count: presenter.rotatable_license_count,
                email: resource.email
              )
            }
  end

  action_item :rotate_all, only: :index, if: proc { current_user&.master_admin? } do
    link_to t("active_admin.subscription_audits.actions.rotate_all"),
            confirm_rotate_all_admin_subscription_audits_path
  end

  sidebar :subscription_audit_filters, only: :index do
    raw_filters = params[:audit]
    audit_filters = raw_filters.respond_to?(:to_unsafe_h) ? raw_filters.to_unsafe_h.with_indifferent_access : {}.with_indifferent_access

    form action: admin_subscription_audits_path, method: :get, class: "filter_form" do
      div class: "filter_form_field filter_string" do
        label t("active_admin.subscription_audits.filters.email"), for: "audit_email"
        input type: "search", id: "audit_email", name: "audit[email]", value: audit_filters[:email]
      end

      div class: "filter_form_field filter_select" do
        label t("active_admin.subscription_audits.filters.source"), for: "audit_source"
        select id: "audit_source", name: "audit[source]" do
          option t("active_admin.subscription_audits.filters.all"), value: ""
          Admin::SubscriptionAudits::Query::SOURCES.each do |source|
            option t("active_admin.subscription_audits.sources.#{source}"),
                   value: source,
                   selected: audit_filters[:source] == source
          end
        end
      end

      div class: "filter_form_field filter_select" do
        label t("active_admin.subscription_audits.filters.status"), for: "audit_status"
        select id: "audit_status", name: "audit[status]" do
          option t("active_admin.subscription_audits.filters.all"), value: ""
          Admin::SubscriptionAudits::Query::STATUSES.each do |status|
            option status.humanize, value: status, selected: audit_filters[:status] == status
          end
        end
      end

      div class: "filter_form_field filter_select" do
        label t("active_admin.subscription_audits.filters.interval"), for: "audit_interval"
        select id: "audit_interval", name: "audit[interval]" do
          option t("active_admin.subscription_audits.filters.all"), value: ""
          Admin::SubscriptionAudits::Query::INTERVALS.each do |interval|
            option interval.humanize, value: interval, selected: audit_filters[:interval] == interval
          end
        end
      end

      div class: "filter_form_field filter_date_range" do
        label t("active_admin.subscription_audits.filters.period_end_from"), for: "audit_period_end_from"
        input type: "date",
              id: "audit_period_end_from",
              name: "audit[period_end_from]",
              value: audit_filters[:period_end_from]
      end

      div class: "filter_form_field filter_date_range" do
        label t("active_admin.subscription_audits.filters.period_end_to"), for: "audit_period_end_to"
        input type: "date",
              id: "audit_period_end_to",
              name: "audit[period_end_to]",
              value: audit_filters[:period_end_to]
      end

      div class: "buttons" do
        input type: "submit", value: t("active_admin.subscription_audits.filters.apply")
        text_node " "
        a t("active_admin.subscription_audits.filters.clear"), href: admin_subscription_audits_path
      end
    end
  end

  index title: proc { t("active_admin.subscription_audits.title") }, download_links: false do
    column t("active_admin.subscription_audits.labels.user") do |audit_user|
      link_to "#{audit_user.email} (##{audit_user.id})", admin_subscription_audit_path(audit_user)
    end
    column t("active_admin.subscription_audits.labels.source") do |audit_user|
      presenter = subscription_audit_presenter(audit_user)
      status_tag t("active_admin.subscription_audits.sources.#{presenter.access_source}")
    end
    column t("active_admin.subscription_audits.labels.status") do |audit_user|
      subscription_audit_presenter(audit_user).status.presence || t("active_admin.subscription_audits.unavailable")
    end
    column t("active_admin.subscription_audits.labels.interval") do |audit_user|
      subscription_audit_presenter(audit_user).interval_label.presence || t("active_admin.subscription_audits.unavailable")
    end
    column t("active_admin.subscription_audits.labels.period_start") do |audit_user|
      subscription_audit_presenter(audit_user).period_start || t("active_admin.subscription_audits.unavailable")
    end
    column t("active_admin.subscription_audits.labels.period_end") do |audit_user|
      subscription_audit_presenter(audit_user).period_end || t("active_admin.subscription_audits.unavailable")
    end
    column t("active_admin.subscription_audits.labels.settled_net") do |audit_user|
      totals = subscription_audit_presenter(audit_user).payment_totals
      if totals.empty?
        t("active_admin.subscription_audits.unavailable")
      else
        safe_join(totals.map do |total|
          admin_currency_from_cents(total[:settled_net_cents], currency: total[:currency])
        end, tag.br)
      end
    end
    column t("active_admin.subscription_audits.labels.refunds") do |audit_user|
      totals = subscription_audit_presenter(audit_user).payment_totals
      if totals.empty?
        t("active_admin.subscription_audits.unavailable")
      else
        safe_join(totals.map do |total|
          admin_currency_from_cents(total[:refunds_cents], currency: total[:currency])
        end, tag.br)
      end
    end
    column t("active_admin.subscription_audits.labels.manual_access") do |audit_user|
      subscription_audit_presenter(audit_user).manual_access_label.presence || t("active_admin.subscription_audits.none")
    end
    column t("active_admin.subscription_audits.labels.license") do |audit_user|
      subscription_audit_presenter(audit_user).license_status_label.presence || t("active_admin.subscription_audits.none")
    end
    actions defaults: false do |audit_user|
      item t("active_admin.subscription_audits.actions.audit"), admin_subscription_audit_path(audit_user)
    end
  end

  show title: proc { |audit_user| t("active_admin.subscription_audits.show_title", email: audit_user.email) } do
    presenter = subscription_audit_presenter(resource)

    if presenter.local_snapshot_warnings.any?
      panel t("active_admin.subscription_audits.sections.freshness") do
        ul do
          presenter.local_snapshot_warnings.each do |warning|
            li t("active_admin.subscription_audits.warnings.#{warning}")
          end
        end
      end
    end

    panel t("active_admin.subscription_audits.sections.account") do
      attributes_table_for resource do
        row(:id)
        row(:email)
        row(:name)
        row(:role)
        row(:preferred_locale)
        row(t("active_admin.subscription_audits.labels.stripe_customer")) do
          presenter.customer_references.join(", ").presence || t("active_admin.subscription_audits.unavailable")
        end
      end
    end

    panel t("active_admin.subscription_audits.sections.current_access") do
      attributes_table_for resource do
        row(t("active_admin.subscription_audits.labels.source")) do
          status_tag t("active_admin.subscription_audits.sources.#{presenter.access_source}")
        end
        row(t("active_admin.subscription_audits.labels.status")) do
          presenter.status.presence || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.plan")) do
          presenter.plan_name.presence || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.processor_plan")) do
          presenter.processor_plan_reference.presence || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.interval")) do
          presenter.interval_label.presence || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.period_start")) do
          presenter.period_start || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.period_end")) do
          presenter.period_end || t("active_admin.subscription_audits.unavailable")
        end
        row(t("active_admin.subscription_audits.labels.cancel_or_end")) do
          presenter.cancellation_or_end_at || t("active_admin.subscription_audits.none")
        end
        row(t("active_admin.subscription_audits.labels.sync_freshness")) do
          presenter.synchronization_at || t("active_admin.subscription_audits.unavailable")
        end
      end

      if presenter.subscriptions.any?
        table_for presenter.subscriptions do
          column t("active_admin.subscription_audits.labels.processor_reference"), &:processor_id
          column t("active_admin.subscription_audits.labels.status"), &:status
          column t("active_admin.subscription_audits.labels.plan") do |subscription|
            info = presenter.price_info_for(subscription)
            info&.dig(:plan)&.name || t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.period_start"), &:current_period_start
          column t("active_admin.subscription_audits.labels.period_end") do |subscription|
            subscription.current_period_end || subscription.ends_at || t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.sync_freshness"), &:updated_at
        end
      else
        para t("active_admin.subscription_audits.empty.subscriptions")
      end
    end

    panel t("active_admin.subscription_audits.sections.totals") do
      if presenter.payment_totals.any?
        table_for presenter.payment_totals do
          column(t("active_admin.subscription_audits.labels.currency")) { |total| total[:currency].upcase }
          column(t("active_admin.subscription_audits.labels.stripe_gross")) do |total|
            admin_currency_from_cents(total[:stripe_gross_cents], currency: total[:currency])
          end
          column(t("active_admin.subscription_audits.labels.refunds")) do |total|
            admin_currency_from_cents(total[:refunds_cents], currency: total[:currency])
          end
          column(t("active_admin.subscription_audits.labels.stripe_net")) do |total|
            admin_currency_from_cents(total[:stripe_net_cents], currency: total[:currency])
          end
          column(t("active_admin.subscription_audits.labels.manual_paid")) do |total|
            admin_currency_from_cents(total[:manual_paid_cents], currency: total[:currency])
          end
          column(t("active_admin.subscription_audits.labels.settled_net")) do |total|
            admin_currency_from_cents(total[:settled_net_cents], currency: total[:currency])
          end
        end
      else
        para t("active_admin.subscription_audits.empty.payments")
      end
    end

    panel t("active_admin.subscription_audits.sections.payment_history") do
      if presenter.payment_history.any?
        table_for presenter.payment_history do
          column t("active_admin.subscription_audits.labels.occurred_at"), &:occurred_at
          column t("active_admin.subscription_audits.labels.kind"), &:kind
          column t("active_admin.subscription_audits.labels.status") do |entry|
            status_tag t("active_admin.subscription_audits.payment_states.#{entry.state}")
          end
          column t("active_admin.subscription_audits.labels.processor_reference") do |entry|
            entry.processor_reference || t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.subscription_reference") do |entry|
            entry.subscription_reference || t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.amount") do |entry|
            entry.amount_cents && entry.currency ?
              admin_currency_from_cents(entry.amount_cents, currency: entry.currency) :
              t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.refunded") do |entry|
            entry.currency ? admin_currency_from_cents(entry.refunded_cents, currency: entry.currency) :
              t("active_admin.subscription_audits.unavailable")
          end
          column t("active_admin.subscription_audits.labels.local_source"), &:source
        end
      else
        para t("active_admin.subscription_audits.empty.payment_history")
      end
    end

    panel t("active_admin.subscription_audits.sections.discounts") do
      if presenter.promotion_entries.any?
        h4 t("active_admin.subscription_audits.labels.promotions")
        table_for presenter.promotion_entries do
          column(t("active_admin.subscription_audits.labels.subscription_reference")) { |entry| entry[:subscription_reference] }
          column(t("active_admin.subscription_audits.labels.code")) { |entry| entry[:code] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.percent")) { |entry| entry[:percent] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.record_status")) { |entry| entry[:record_status] }
          column(t("active_admin.subscription_audits.labels.local_source")) { |entry| entry[:source] }
        end
      else
        para t("active_admin.subscription_audits.empty.promotions")
      end

      if presenter.referral_entries.any?
        h4 t("active_admin.subscription_audits.labels.applied_referrals")
        table_for presenter.referral_entries do
          column(t("active_admin.subscription_audits.labels.subscription_reference")) { |entry| entry[:subscription_reference] }
          column(t("active_admin.subscription_audits.labels.code")) { |entry| entry[:code] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.percent")) { |entry| entry[:percent] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.local_source")) { |entry| entry[:source] }
        end
      else
        para t("active_admin.subscription_audits.empty.applied_referrals")
      end

      if presenter.referral_relationship
        h4 t("active_admin.subscription_audits.labels.referral_relationship")
        table_for [ presenter.referral_relationship ] do
          column(t("active_admin.subscription_audits.labels.code")) { |entry| entry[:code] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.referrer_id")) { |entry| entry[:referrer_id] }
          column(t("active_admin.subscription_audits.labels.percent")) { |entry| entry[:discount_percent] || t("active_admin.subscription_audits.unavailable") }
          column(t("active_admin.subscription_audits.labels.completed_at")) { |entry| entry[:completed_at] || t("active_admin.subscription_audits.none") }
        end
      end
    end

    panel t("active_admin.subscription_audits.sections.manual_grants") do
      if presenter.manual_grants.any?
        table_for presenter.manual_grants do
          column(:id) { |grant| link_to grant.id, admin_manual_subscription_path(grant) }
          column(t("active_admin.subscription_audits.labels.plan")) { |grant| grant.billing_plan.name }
          column :granted_days
          column :starts_at
          column :ends_at
          column :status
          column :payment_status
          column(t("active_admin.subscription_audits.labels.amount")) do |grant|
            admin_currency_from_cents(grant.amount_cents, currency: grant.currency)
          end
          column :paid_at
          column :payment_method
          column :reference
          column :notes
          column :recorded_by_admin
          column :superseded_at
          column :superseded_by_pay_subscription
        end
      else
        para t("active_admin.subscription_audits.empty.manual_grants")
      end
    end

    panel t("active_admin.subscription_audits.sections.licenses") do
      if presenter.licenses.any?
        table_for presenter.licenses do
          column :id
          column(:expert_advisor) { |license| license.expert_advisor.name }
          column :status
          column :access_source
          column :source
          column(t("active_admin.subscription_audits.labels.expires_at"), &:effective_expires_at)
          column :token_version
          column :token_rotated_at
          column :last_synced_at
        end
      else
        para t("active_admin.subscription_audits.empty.licenses")
      end
    end

    panel t("active_admin.subscription_audits.sections.admin_events") do
      if presenter.audit_events.any?
        table_for presenter.audit_events do
          column :created_at
          column(t("active_admin.subscription_audits.labels.actor")) { |event| event.actor.email }
          column(t("active_admin.subscription_audits.labels.action")) do |event|
            key = event.action.tr(".", "_")
            t("active_admin.subscription_audits.events.#{key}")
          end
          column :request_id
          column(t("active_admin.subscription_audits.labels.affected_count")) do |event|
            event.metadata["affected_license_count"] || (event.metadata["manual_subscription_id"].present? ? 1 : 0)
          end
          column(t("active_admin.subscription_audits.labels.affected_ids")) do |event|
            license_ids = presenter.event_license_ids(event)
            if license_ids.any?
              license_ids.map { |id| "##{id}" }.join(", ")
            elsif event.metadata["manual_subscription_id"]
              "ManualSubscription##{event.metadata['manual_subscription_id']}"
            else
              t("active_admin.subscription_audits.none")
            end
          end
        end
      else
        para t("active_admin.subscription_audits.empty.admin_events")
      end
    end
  end
end
