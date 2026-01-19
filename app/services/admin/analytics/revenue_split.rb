module Admin
  module Analytics
    class RevenueSplit
      Result = Struct.new(
        :rule,
        :us_percent,
        :client_percent,
        :us_cents,
        :client_cents,
        :missing_rule,
        keyword_init: true
      )

      def initialize(net_cents:, as_of: Time.current, rule: nil)
        @net_cents = net_cents.to_i
        @as_of = as_of
        @rule = rule
      end

      def call
        active_rule = rule || RevenueSplitRule.current(as_of: as_of)
        return fallback if active_rule.blank?

        us_percent = active_rule.us_percent.to_i
        client_percent = active_rule.client_percent.to_i
        us_cents = (@net_cents * (us_percent / 100.0)).round
        client_cents = @net_cents - us_cents

        Result.new(
          rule: active_rule,
          us_percent: us_percent,
          client_percent: client_percent,
          us_cents: us_cents,
          client_cents: client_cents,
          missing_rule: false
        )
      end

      private

      attr_reader :as_of, :rule

      def fallback
        Result.new(
          rule: nil,
          us_percent: 100,
          client_percent: 0,
          us_cents: @net_cents,
          client_cents: 0,
          missing_rule: true
        )
      end
    end
  end
end
