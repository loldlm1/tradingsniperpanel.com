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
          broker_account = upsert_broker_account(result.license)
          render json: {
            ok: true,
            plan_interval: result.plan_interval,
            trial: result.trial,
            expires_at: result.expires_at&.to_i,
            broker_account: broker_account ? serialize_broker_account(broker_account) : nil
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

      def broker_account_params
        params.fetch(:broker_account, {}).permit(:name, :company, :account_number, :account_type)
      end

      def upsert_broker_account(license)
        attrs = broker_account_params
        return nil if attrs.blank?

        company = attrs[:company].to_s.strip
        account_number = safe_account_number(attrs[:account_number])
        account_type = attrs[:account_type].to_s
        name = attrs[:name].presence

        return nil if company.blank? || account_number.nil?
        return nil unless BrokerAccount.account_types.key?(account_type)

        broker_account = nil

        ApplicationRecord.transaction(requires_new: true) do
          broker_account = BrokerAccount.find_or_create_by!(
            company: company,
            account_number: account_number,
            account_type: account_type
          ) do |acct|
            acct.name = name
            acct.license = license
          end

          if broker_account.license_id != license.id
            broker_account.update!(license:)
          elsif name.present? && broker_account.name.blank?
            broker_account.update!(name:)
          end
        end

        broker_account
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def safe_account_number(raw)
        return nil if raw.blank?

        Integer(raw.to_s, 10)
      rescue ArgumentError, TypeError
        nil
      end

      def serialize_broker_account(account)
        {
          name: account.name,
          company: account.company,
          account_number: account.account_number,
          account_type: account.account_type
        }
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
