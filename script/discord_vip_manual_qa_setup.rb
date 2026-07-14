# frozen_string_literal: true

module DiscordVipManualQaSetup
  module_function

  PASSWORD = "Password123!"
  ADMIN_EMAIL = "qa.discord.admin@example.com"
  USER_PREFIX = "qa.discord"
  REFERENCE_PREFIX = "discord-vip-qa"
  BASE_SNOWFLAKE = 9_100_000_000_000_000_000
  STATES = %i[
    ineligible
    eligible_unlinked
    linked_pending
    membership_screening
    granted
    expired_removed
    sync_failed
    disconnecting
  ].freeze

  def run!
    raise "Discord VIP QA setup refuses to run in production." if Rails.env.production?

    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    records = ApplicationRecord.transaction do
      admin = ensure_user!(email: ADMIN_EMAIL, name: "QA Discord Admin", role: :admin)
      plans = ensure_plans!

      STATES.index_with do |state|
        setup_state!(state:, admin:, plan: plans.fetch(:monthly))
      end
    end

    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    print_summary(records)
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter if previous_adapter
  end

  def ensure_plans!
    {
      monthly: ensure_plan!(
        key: Billing::PandoraPricing::MONTHLY_KEY,
        name: "Pandora Box Monthly",
        interval: "month",
        amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
        suffix: "monthly"
      ),
      annual: ensure_plan!(
        key: Billing::PandoraPricing::ANNUAL_KEY,
        name: "Pandora Box Annual",
        interval: "year",
        amount_cents: Billing::PandoraPricing::ANNUAL_CENTS,
        suffix: "annual"
      )
    }
  end

  def ensure_plan!(key:, name:, interval:, amount_cents:, suffix:)
    plan = BillingPlan.find_or_initialize_by(key: key)
    if plan.new_record?
      plan.assign_attributes(
        name: name,
        kind: :subscription,
        tier: Billing::PandoraPricing::TIER,
        interval: interval,
        interval_count: 1,
        amount_cents: amount_cents,
        currency: Billing::PandoraPricing::CURRENCY,
        active: true,
        stripe_product_id: "prod_discord_vip_qa",
        stripe_price_id: "price_discord_vip_qa_#{suffix}"
      )
      plan.save!
    end

    unless BillingPlan.purchasable.where(id: plan.id).exists?
      raise "Canonical Pandora plan #{key} is not purchasable; run catalog setup first."
    end

    plan
  end

  def setup_state!(state:, admin:, plan:)
    user = ensure_user!(
      email: "#{USER_PREFIX}.#{state}@example.com",
      name: "QA Discord #{state.to_s.humanize}",
      role: :trader
    )
    ensure_no_processor_data!(user)

    subscription = if state == :ineligible
      ManualSubscription.where(user: user).delete_all
      nil
    elsif state == :expired_removed
      ensure_manual_subscription!(user:, admin:, plan:, active: false)
    else
      ensure_manual_subscription!(user:, admin:, plan:, active: true)
    end

    connection = build_connection!(user:, state:)
    { user: user, subscription: subscription, connection: connection }
  end

  def ensure_user!(email:, name:, role:)
    user = User.find_or_initialize_by(email: email)
    user.assign_attributes(
      name: name,
      role: role,
      preferred_locale: "en",
      terms_accepted_at: user.terms_accepted_at || Time.current,
      password: PASSWORD,
      password_confirmation: PASSWORD
    )
    user.save!
    user
  end

  def ensure_no_processor_data!(user)
    return unless user.pay_customers.exists?

    raise "QA user #{user.id} has processor data; remove it before rebuilding Discord QA states."
  end

  def ensure_manual_subscription!(user:, admin:, plan:, active:)
    now = Time.current.change(usec: 0)
    starts_at = active ? now - 1.day : now - 31.days
    ends_at = active ? now + 30.days : now - 1.day
    subscription = ManualSubscription.find_or_initialize_by(
      user: user,
      reference: "#{REFERENCE_PREFIX}-#{user.id}"
    )
    ManualSubscription.where(user: user).where.not(id: subscription.id).delete_all
    subscription.assign_attributes(
      billing_plan: plan,
      amount_cents: plan.amount_cents,
      granted_days: 30,
      payment_status: :paid,
      currency: plan.currency,
      paid_at: starts_at,
      starts_at: starts_at,
      ends_at: ends_at,
      status: active ? :active : :expired,
      recorded_by_admin: admin,
      payment_method: "qa",
      notes: "Deterministic Discord VIP browser QA state"
    )
    subscription.save!
    subscription
  end

  def build_connection!(user:, state:)
    if state.in?(%i[ineligible eligible_unlinked])
      DiscordConnection.where(user: user).delete_all
      return
    end

    now = Time.current.change(usec: 0)
    attributes = {
      discord_user_id: (BASE_SNOWFLAKE + STATES.index(state)).to_s,
      discord_username: "qa-#{state.to_s.tr('_', '-')}",
      discord_global_name: "QA #{state.to_s.humanize}",
      linked_at: now - 1.day,
      membership_pending: false,
      vip_role_state: "unknown",
      sync_status: "idle",
      last_synced_at: now - 1.hour
    }

    case state
    when :linked_pending
      attributes[:membership_pending] = true
      attributes[:vip_role_state] = "pending"
      attributes[:sync_status] = "queued"
    when :membership_screening
      attributes[:membership_pending] = true
      attributes[:vip_role_state] = "granted"
    when :granted
      attributes[:vip_role_state] = "granted"
    when :expired_removed
      attributes[:vip_role_state] = "removed"
    when :sync_failed
      attributes[:sync_status] = "failed"
      attributes[:last_error_code] = "qa_provider_failure"
      attributes[:last_error_at] = now - 5.minutes
    when :disconnecting
      attributes[:vip_role_state] = "granted"
      attributes[:disconnect_requested_at] = now - 5.minutes
    end

    connection = DiscordConnection.find_or_initialize_by(user: user)
    connection.assign_attributes(
      **attributes,
      disconnect_requested_at: attributes[:disconnect_requested_at],
      disconnected_at: nil,
      sync_started_at: nil,
      last_error_code: attributes[:last_error_code],
      last_error_at: attributes[:last_error_at]
    )
    connection.save!
    connection
  end

  def print_summary(records)
    puts "DISCORD_VIP_QA_READY"
    puts "qa_password=#{PASSWORD}"
    records.each do |state, record|
      connection = record.fetch(:connection)
      puts [
        "state=#{state}",
        "email=#{record.fetch(:user).email}",
        "user_id=#{record.fetch(:user).id}",
        "connection_id=#{connection&.id || 'none'}"
      ].join(" ")
    end
    puts "state_count=#{records.size}"
  end
end

DiscordVipManualQaSetup.run!
