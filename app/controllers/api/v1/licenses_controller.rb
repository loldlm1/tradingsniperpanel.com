module Api
  module V1
    class LicensesController < ActionController::API
      before_action :ensure_json
      before_action :reject_if_rate_limited

      def verify
        result = verifier.call(
          source: params[:source],
          email: params[:email],
          ea_id: params[:ea_id],
          license_key: params[:license_key]
        )

        if result.ok?
          render json: {
            ok: true,
            plan_interval: result.plan_interval,
            trial: result.trial,
            expires_at: result.expires_at&.iso8601
          }
        else
          render json: { ok: false, error: result.error }, status: result.code
        end
      rescue StandardError => e
        Rails.logger.error("LicensesController#verify failed: #{e.class} - #{e.message}")
        render json: { ok: false, error: :internal_error }, status: :internal_server_error
      end

      private

      def verifier
        @verifier ||= Licenses::LicenseVerifier.new
      end

      def ensure_json
        request.format = :json
      end

      def reject_if_rate_limited
        return unless rate_limited?

        render json: { ok: false, error: :rate_limited }, status: :too_many_requests
      end

      def rate_limited?
        return false unless defined?(Rails.cache)

        key = "licenses/verify/#{params[:email].to_s.downcase}"
        count = Rails.cache.increment(key, 1, expires_in: 1.minute)
        count && count > 60
      rescue StandardError
        false
      end
    end
  end
end
