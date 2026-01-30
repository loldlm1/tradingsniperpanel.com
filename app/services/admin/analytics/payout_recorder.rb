module Admin
  module Analytics
    class PayoutRecorder
      Result = Struct.new(:payout, :errors, keyword_init: true) do
        def ok?
          errors.blank?
        end
      end

      def initialize(period_key:, as_of:, actor:, notes: nil)
        @period_key = period_key.to_s
        @as_of = as_of
        @actor = actor
        @notes = notes
      end

      def call
        return Result.new(payout: nil, errors: ["Unauthorized"]) unless admin_actor?

        period = PeriodResolver.new(key: period_key, as_of: parsed_as_of).call
        payout = RevenueSplitPayout.find_or_initialize_by(
          period_key: period.key,
          starts_at: period.starts_at,
          ends_at: period.ends_at
        )

        if payout.persisted?
          payout.errors.add(:base, :taken)
          return Result.new(payout: payout, errors: payout.errors.full_messages)
        end

        stats = RevenueMetrics.new(starts_at: period.starts_at, ends_at: period.ends_at).call
        split = RevenueSplit.new(net_cents: stats.net_cents, as_of: period.ends_at).call

        payout.assign_attributes(
          net_cents: stats.net_cents,
          us_cents: split.us_cents,
          client_cents: split.client_cents,
          status: :paid,
          paid_at: Time.current,
          paid_by_admin: actor,
          notes: notes
        )

        if payout.save
          Result.new(payout: payout, errors: [])
        else
          Result.new(payout: payout, errors: payout.errors.full_messages)
        end
      end

      private

      attr_reader :period_key, :as_of, :actor, :notes

      def admin_actor?
        actor&.admin? || actor&.master_admin?
      end

      def parsed_as_of
        return Time.current if as_of.blank?
        return as_of if as_of.respond_to?(:in_time_zone)

        Time.zone.parse(as_of.to_s)
      rescue ArgumentError
        Time.current
      end
    end
  end
end
