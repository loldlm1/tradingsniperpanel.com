module Api
  module V1
    class BrokerAccountDailyResultsController < ActionController::API
      before_action :ensure_json

      def create
        result = recorder.call(
          source: params[:source],
          email: params[:email],
          ea_id: params[:ea_id],
          license_key: params[:license_key],
          broker_account: broker_account_params.to_h,
          result_timestamp: params[:result_timestamp],
          result_value: params[:result_value]
        )

        if result.ok?
          daily_result = result.daily_result
          render json: {
            ok: true,
            broker_account_id: daily_result.broker_account_id,
            result_on: daily_result.result_on&.iso8601,
            result_value: format("%.2f", daily_result.result_value)
          }, status: result.code
        else
          render json: { ok: false, error: result.error }, status: result.code
        end
      rescue StandardError => e
        Rails.logger.error(
          "BrokerAccountDailyResultsController#create failed: #{e.class} - #{e.message} email=#{params[:email]} ea_id=#{params[:ea_id]}"
        )
        render json: { ok: false, error: :internal_error }, status: :internal_server_error
      end

      private

      def recorder
        @recorder ||= BrokerAccounts::DailyResultRecorder.new
      end

      def broker_account_params
        params.fetch(:broker_account, {}).permit(:company, :account_number, :account_type)
      end

      def ensure_json
        request.format = :json
      end
    end
  end
end
