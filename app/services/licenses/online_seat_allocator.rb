module Licenses
  class OnlineSeatAllocator
    Result = Struct.new(:ok, :code, :error, :session, :entitlement_source, :details, keyword_init: true) do
      def ok?
        !!self[:ok]
      end
    end

    DEFAULT_TTL_SECONDS = 15.minutes.to_i

    def initialize(license:, broker_account:, now: Time.current, ttl_seconds: DEFAULT_TTL_SECONDS, logger: Rails.logger)
      @license = license
      @broker_account = broker_account
      @now = now
      @ttl_seconds = ttl_seconds.to_i.positive? ? ttl_seconds.to_i : DEFAULT_TTL_SECONDS
      @logger = logger
    end

    def call
      identity = normalize_identity(broker_account)
      return failure(:invalid_payload, :unprocessable_content) if identity.nil?

      result = nil

      ApplicationRecord.transaction do
        license.user.lock!

        existing_session = find_session(identity)
        limits = OnlineSeatLimits.new(user: license.user, expert_advisor: license.expert_advisor, now: now)
        subscription_cap = effective_subscription_cap(limits)
        selected_source = select_source(
          limits: limits,
          existing_session: existing_session,
          subscription_cap: subscription_cap
        )

        if selected_source.nil?
          existing_session&.destroy!
          result = failure(
            :online_limit_reached,
            :too_many_requests,
            usage_details(
              limits: limits,
              existing_session: nil,
              subscription_cap: subscription_cap
            )
          )
          raise ActiveRecord::Rollback
        end

        session = existing_session || build_session(identity)
        session.entitlement_source = selected_source
        session.last_seen_at = now
        session.save!

        result = success(
          session,
          selected_source,
          usage_details(
            limits: limits,
            existing_session: session,
            subscription_cap: subscription_cap
          )
        )
      end

      result || failure(:internal_error, :internal_server_error)
    rescue ActiveRecord::RecordInvalid => e
      logger.warn("[Licenses::OnlineSeatAllocator] invalid payload user_id=#{license.user_id} ea_id=#{license.expert_advisor_id}: #{e.record.errors.full_messages.join(', ')}")
      failure(:invalid_payload, :unprocessable_content)
    rescue StandardError => e
      logger.error("[Licenses::OnlineSeatAllocator] failed user_id=#{license.user_id} ea_id=#{license.expert_advisor_id}: #{e.class} - #{e.message}")
      failure(:internal_error, :internal_server_error)
    end

    private

    Identity = Struct.new(:company, :account_number, :account_type, keyword_init: true)

    attr_reader :license, :broker_account, :now, :ttl_seconds, :logger

    def cutoff_time
      now - ttl_seconds.seconds
    end

    def normalize_identity(raw)
      attrs = raw.to_h.symbolize_keys
      return nil if attrs.blank?

      company = attrs[:company].to_s.strip.downcase
      account_number = safe_account_number(attrs[:account_number])
      account_type = attrs[:account_type].to_s

      return nil if company.blank? || account_number.nil?
      return nil unless LicenseOnlineSession.account_types.key?(account_type)

      Identity.new(company: company, account_number: account_number, account_type: account_type)
    end

    def safe_account_number(raw)
      return nil if raw.blank?

      Integer(raw.to_s, 10)
    rescue ArgumentError, TypeError
      nil
    end

    def find_session(identity)
      LicenseOnlineSession.find_by(
        user_id: license.user_id,
        expert_advisor_id: license.expert_advisor_id,
        company: identity.company,
        account_number: identity.account_number,
        account_type: identity.account_type
      )
    end

    def build_session(identity)
      LicenseOnlineSession.new(
        user_id: license.user_id,
        expert_advisor_id: license.expert_advisor_id,
        company: identity.company,
        account_number: identity.account_number,
        account_type: identity.account_type
      )
    end

    def select_source(limits:, existing_session:, subscription_cap:)
      candidate_sources = []
      candidate_sources << "one_time" if limits.one_time_cap.positive?
      candidate_sources << "subscription" if subscription_cap.positive?

      candidate_sources.find do |source|
        source_capacity_available?(
          source: source,
          limits: limits,
          existing_session: existing_session,
          subscription_cap: subscription_cap
        )
      end
    end

    def source_capacity_available?(source:, limits:, existing_session:, subscription_cap:)
      scope = active_scope(existing_session: existing_session)

      case source
      when "one_time"
        in_use = scope.where(expert_advisor_id: license.expert_advisor_id, entitlement_source: "one_time").count
        in_use < limits.one_time_cap
      when "subscription"
        in_use = scope.where(entitlement_source: "subscription").count
        in_use < subscription_cap
      else
        false
      end
    end

    def active_scope(existing_session:)
      scope = LicenseOnlineSession
              .where(user_id: license.user_id)
              .active_since(cutoff_time)

      return scope unless existing_session

      scope.where.not(id: existing_session.id)
    end

    def usage_details(limits:, existing_session:, subscription_cap:)
      scope = active_scope(existing_session: existing_session)

      {
        subscription_cap: subscription_cap,
        subscription_in_use: scope.where(entitlement_source: "subscription").count,
        one_time_cap: limits.one_time_cap,
        one_time_in_use: scope.where(expert_advisor_id: license.expert_advisor_id, entitlement_source: "one_time").count,
        ttl_seconds: ttl_seconds
      }
    end

    def effective_subscription_cap(limits)
      cap = limits.subscription_cap
      return cap if cap.positive?
      return 0 unless license.access_source_subscription? && license.active_for_request?

      OnlineSeatLimits::BASE_SUBSCRIPTION_CAP
    end

    def success(session, entitlement_source, details)
      Result.new(
        ok: true,
        code: :ok,
        session: session,
        entitlement_source: entitlement_source,
        details: details
      )
    end

    def failure(error, code, details = nil)
      Result.new(ok: false, error: error, code: code, details: details)
    end
  end
end
