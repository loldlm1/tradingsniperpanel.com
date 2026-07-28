module Admin
  module SubscriptionAudits
    class Query
      SOURCES = %w[stripe manual mixed].freeze
      STATUSES = (Pay::Subscription::STATUSES + ManualSubscription::STATUSES.values).uniq.freeze
      INTERVALS = BillingPlan::INTERVALS.freeze

      MAX_CUSTOMERS_PER_USER = 10
      MAX_SUBSCRIPTIONS_PER_USER = 50
      MAX_CHARGES_PER_USER = 100
      MAX_MANUAL_GRANTS_PER_USER = 100
      MAX_LICENSES_PER_USER = 100
      MAX_WEBHOOKS_PER_CUSTOMER = 100
      MAX_AUDIT_EVENTS_PER_USER = 100
      MAX_GLOBAL_AUDIT_EVENTS = 100

      Context = Struct.new(
        :customers_by_user,
        :subscriptions_by_user,
        :charges_by_user,
        :manual_grants_by_user,
        :licenses_by_user,
        :webhooks_by_user,
        :price_lookup,
        :promotion_lookup,
        :referrals_by_user,
        :partner_profiles_by_user,
        :audit_events_by_user,
        :global_audit_events,
        keyword_init: true
      )

      def initialize(scope: User.all, filters: {})
        @scope = scope
        @filters = extract_filters(filters)
      end

      def call
        relation = history_scope
        relation = filter_email(relation)
        relation = filter_source(relation)
        relation = filter_status(relation)
        relation = filter_interval(relation)
        filter_period_end(relation)
      end

      def presenters_for(users)
        users = Array(users)
        context = build_context(users)
        users.to_h { |user| [ user.id, Presenter.new(user: user, context: context) ] }
      end

      private

      attr_reader :scope, :filters

      def extract_filters(value)
        raw = value.respond_to?(:to_unsafe_h) ? value.to_unsafe_h : value.to_h
        (raw["audit"] || raw[:audit] || raw).with_indifferent_access
      end

      def history_scope
        stripe = scope.where(id: stripe_user_ids)
        manual = scope.where(id: ManualSubscription.select(:user_id))
        stripe.or(manual)
      end

      def filter_email(relation)
        term = filters[:email].to_s.strip
        return relation if term.blank?

        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
        relation.where("users.email ILIKE ?", pattern)
      end

      def filter_source(relation)
        source = filters[:source].to_s
        return relation unless SOURCES.include?(source)

        case source
        when "stripe"
          relation.where(id: stripe_user_ids)
        when "manual"
          relation.where(id: ManualSubscription.select(:user_id))
        when "mixed"
          relation.where(id: stripe_user_ids).where(id: ManualSubscription.select(:user_id))
        end
      end

      def filter_status(relation)
        status = filters[:status].to_s
        return relation unless STATUSES.include?(status)

        stripe = relation.where(id: stripe_user_ids(Pay::Subscription.where(status: status)))
        manual = relation.where(id: ManualSubscription.where(status: status).select(:user_id))
        stripe.or(manual)
      end

      def filter_interval(relation)
        interval = filters[:interval].to_s
        return relation unless INTERVALS.include?(interval)

        price_ids = BillingPlan.where(interval: interval).where.not(stripe_price_id: nil).pluck(:stripe_price_id)
        price_ids.concat(BillingPlanPrice.where(interval: interval).pluck(:stripe_price_id))
        stripe_subscriptions = Pay::Subscription.where(processor_plan: price_ids.uniq)
        stripe = relation.where(id: stripe_user_ids(stripe_subscriptions))
        manual = relation.where(
          id: ManualSubscription.joins(:billing_plan).where(billing_plans: { interval: interval }).select(:user_id)
        )
        stripe.or(manual)
      end

      def filter_period_end(relation)
        from = parsed_date(filters[:period_end_from])&.beginning_of_day
        to = parsed_date(filters[:period_end_to])&.end_of_day
        return relation unless from || to

        subscriptions = Pay::Subscription.all
        manual_grants = ManualSubscription.all
        subscriptions = subscriptions.where("COALESCE(current_period_end, ends_at) >= ?", from) if from
        subscriptions = subscriptions.where("COALESCE(current_period_end, ends_at) <= ?", to) if to
        manual_grants = manual_grants.where("ends_at >= ?", from) if from
        manual_grants = manual_grants.where("ends_at <= ?", to) if to

        stripe = relation.where(id: stripe_user_ids(subscriptions))
        manual = relation.where(id: manual_grants.select(:user_id))
        stripe.or(manual)
      end

      def stripe_user_ids(subscriptions = Pay::Subscription.all)
        customer_ids = subscriptions.select(:customer_id)
        Pay::Customer.where(owner_type: "User", id: customer_ids).select(:owner_id)
      end

      def parsed_date(value)
        Date.iso8601(value.to_s)
      rescue Date::Error
        nil
      end

      def build_context(users)
        user_ids = users.map(&:id)
        customers = load_customers(user_ids)
        customer_ids = customers.map(&:id)
        subscriptions = load_pay_records(Pay::Subscription, customer_ids, MAX_SUBSCRIPTIONS_PER_USER)
        charges = load_pay_records(Pay::Charge, customer_ids, MAX_CHARGES_PER_USER)
        manual_grants = load_manual_grants(user_ids)
        licenses = load_licenses(user_ids)
        webhooks = load_webhooks(customers)
        referrals, profiles = load_referrals(user_ids)
        audit_events, global_events = load_audit_events(user_ids)

        Context.new(
          customers_by_user: customers.group_by(&:owner_id),
          subscriptions_by_user: group_by_audit_owner(subscriptions),
          charges_by_user: group_by_audit_owner(charges),
          manual_grants_by_user: manual_grants.group_by(&:user_id),
          licenses_by_user: licenses.group_by(&:user_id),
          webhooks_by_user: webhooks,
          price_lookup: load_price_lookup(subscriptions),
          promotion_lookup: load_promotions(subscriptions),
          referrals_by_user: referrals.index_by(&:referee_id),
          partner_profiles_by_user: profiles.index_by(&:user_id),
          audit_events_by_user: audit_events.group_by(&:target_id),
          global_audit_events: global_events
        )
      end

      def load_customers(user_ids)
        relation = Pay::Customer.where(owner_type: "User", owner_id: user_ids)
        limited_relation(
          relation,
          partition: "pay_customers.owner_id",
          order: "pay_customers.default DESC NULLS LAST, pay_customers.created_at DESC, pay_customers.id DESC",
          limit: MAX_CUSTOMERS_PER_USER
        ).to_a
      end

      def load_pay_records(model, customer_ids, limit)
        return [] if customer_ids.empty?

        table = model.table_name
        relation = model.joins(:customer).where(customer_id: customer_ids).select(
          "#{table}.*",
          "pay_customers.owner_id AS audit_owner_id"
        )
        limited_relation(
          relation,
          partition: "pay_customers.owner_id",
          order: "#{table}.created_at DESC, #{table}.id DESC",
          limit: limit
        ).to_a
      end

      def load_manual_grants(user_ids)
        relation = ManualSubscription.where(user_id: user_ids)
        limited_relation(
          relation,
          partition: "manual_subscriptions.user_id",
          order: "manual_subscriptions.created_at DESC, manual_subscriptions.id DESC",
          limit: MAX_MANUAL_GRANTS_PER_USER
        ).preload(:billing_plan, :recorded_by_admin, :superseded_by_pay_subscription).to_a
      end

      def load_licenses(user_ids)
        subscription_ea_ids = Billing::SubscriptionCatalog.products.flat_map(&:ea_ids).uniq
        relation = License.joins(:expert_advisor)
                          .where(user_id: user_ids, expert_advisors: { ea_id: subscription_ea_ids })
        limited_relation(
          relation,
          partition: "licenses.user_id",
          order: "licenses.updated_at DESC, licenses.id DESC",
          limit: MAX_LICENSES_PER_USER
        ).preload(:expert_advisor).to_a
      end

      def load_webhooks(customers)
        customer_references = customers.filter_map(&:processor_id).uniq
        return {} if customer_references.empty?

        expression = "COALESCE(event #>> '{data,object,customer}', event #>> '{data,object,customer,id}')"
        relation = Pay::Webhook.where(processor: "stripe")
                               .where("event_type LIKE ?", "invoice.%")
                               .where("#{expression} IN (?)", customer_references)
                               .select("pay_webhooks.*", "#{expression} AS audit_customer_reference")
        records = limited_relation(
          relation,
          partition: expression,
          order: "pay_webhooks.created_at DESC, pay_webhooks.id DESC",
          limit: MAX_WEBHOOKS_PER_CUSTOMER
        ).to_a
        owner_by_customer = customers.to_h { |customer| [ customer.processor_id, customer.owner_id ] }

        records.group_by { |record| owner_by_customer[record["audit_customer_reference"]] }.compact
      end

      def load_price_lookup(subscriptions)
        price_ids = subscriptions.filter_map(&:processor_plan).uniq
        histories = BillingPlanPrice.includes(:billing_plan).where(stripe_price_id: price_ids).to_a
        lookup = histories.to_h do |history|
          [
            history.stripe_price_id,
            {
              plan: history.billing_plan,
              amount_cents: history.amount_cents,
              currency: history.currency,
              interval: history.interval,
              interval_count: history.interval_count,
              historical: !history.current?
            }
          ]
        end

        missing_ids = price_ids - lookup.keys
        BillingPlan.where(stripe_price_id: missing_ids).find_each do |plan|
          lookup[plan.stripe_price_id] = {
            plan: plan,
            amount_cents: plan.amount_cents,
            currency: plan.currency,
            interval: plan.interval,
            interval_count: plan.interval_count,
            historical: false
          }
        end
        lookup
      end

      def load_promotions(subscriptions)
        metadata = subscriptions.filter_map { |subscription| safe_metadata(subscription) }
        ids = metadata.filter_map { |entry| Integer(entry["dashboard_promotion_id"], exception: false) }.uniq
        codes = metadata.filter_map { |entry| entry["dashboard_promotion_code"].to_s.presence }.uniq
        by_id = ids.any? ? PromotionCode.where(id: ids) : PromotionCode.none
        by_code = codes.any? ? PromotionCode.where(code: codes) : PromotionCode.none
        by_id.or(by_code).to_a.each_with_object({}) do |promotion, lookup|
          lookup[promotion.id.to_s] = promotion
          lookup[promotion.code] = promotion
        end
      end

      def load_referrals(user_ids)
        referrals = Refer::Referral.where(referee_type: "User", referee_id: user_ids)
                                    .includes(:referral_code, :referrer)
                                    .to_a
        referrer_ids = referrals.filter_map do |referral|
          referral.referrer_id if referral.referrer_type == "User"
        end
        profiles = PartnerProfile.where(user_id: referrer_ids).to_a
        [ referrals, profiles ]
      end

      def load_audit_events(user_ids)
        targeted = AdminAuditEvent.where(target_type: "User", target_id: user_ids)
        targeted = limited_relation(
          targeted,
          partition: "admin_audit_events.target_id",
          order: "admin_audit_events.created_at DESC, admin_audit_events.id DESC",
          limit: MAX_AUDIT_EVENTS_PER_USER
        ).includes(:actor).to_a
        global = AdminAuditEvent.where(
          action: AdminAuditEvent::ACTIONS.fetch(:all_licenses_rotated),
          target_type: nil,
          target_id: nil
        ).includes(:actor).recent_first.limit(MAX_GLOBAL_AUDIT_EVENTS).to_a
        [ targeted, global ]
      end

      def limited_relation(relation, partition:, order:, limit:)
        table = relation.klass.table_name
        ranked = relation.select(
          "#{table}.*",
          "ROW_NUMBER() OVER (PARTITION BY #{partition} ORDER BY #{order}) AS audit_row_number"
        )
        relation.klass.unscoped
                .from("(#{ranked.to_sql}) #{table}")
                .where("#{table}.audit_row_number <= ?", limit)
      end

      def group_by_audit_owner(records)
        records.group_by { |record| record["audit_owner_id"].to_i }
      end

      def safe_metadata(subscription)
        return subscription.metadata if subscription.metadata.is_a?(Hash) && subscription.metadata.present?

        object_metadata = subscription.object.is_a?(Hash) ? subscription.object["metadata"] : nil
        object_metadata if object_metadata.is_a?(Hash) && object_metadata.present?
      end
    end
  end
end
