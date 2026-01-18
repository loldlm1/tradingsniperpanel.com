module Admin
  module Analytics
    Period = Struct.new(:key, :label, :starts_at, :ends_at, keyword_init: true)

    class PeriodResolver
      PERIOD_KEYS = %w[first_half second_half monthly].freeze

      def initialize(key:, as_of: Time.current, time_zone: "UTC")
        @key = key.to_s
        @as_of = as_of
        @time_zone = time_zone
      end

      def call
        Time.use_zone(time_zone) do
          as_of = @as_of.in_time_zone(Time.zone)

          starts_at, ends_at = case key
                               when "first_half"
                                 first_half_range(as_of)
                               when "second_half"
                                 second_half_range(as_of)
                               when "monthly"
                                 [as_of.beginning_of_month, as_of.end_of_month]
                               else
                                 raise ArgumentError, "unknown period key: #{key}"
                               end

          Period.new(
            key: key,
            label: I18n.t("active_admin.dashboard.periods.#{key}"),
            starts_at: starts_at.beginning_of_day,
            ends_at: ends_at.end_of_day
          )
        end
      end

      private

      attr_reader :key, :time_zone

      def first_half_range(as_of)
        month_start = as_of.beginning_of_month
        [month_start, month_start + 14.days]
      end

      def second_half_range(as_of)
        month_start = as_of.beginning_of_month
        [month_start + 15.days, as_of.end_of_month]
      end
    end
  end
end
