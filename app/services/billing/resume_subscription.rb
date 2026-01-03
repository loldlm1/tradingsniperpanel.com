module Billing
  class ResumeSubscription
    Result = Struct.new(:status, :error, keyword_init: true) do
      def success?
        status == :resumed
      end
    end

    def initialize(subscription:, user: nil, logger: Rails.logger, locale: I18n.locale)
      @subscription = subscription
      @user = user
      @logger = logger
      @locale = locale
    end

    def call
      return Result.new(status: :no_subscription) if subscription.blank?
      return Result.new(status: :not_resumable) unless resumable?

      subscription.resume
      subscription.sync! if subscription.respond_to?(:sync!)
      subscription.reload

      Result.new(status: :resumed)
    rescue StandardError => e
      logger.error(
        "[Billing::ResumeSubscription] failed user_id=#{user&.id} subscription_id=#{subscription&.id} processor_id=#{subscription&.processor_id} locale=#{locale}: #{e.class} - #{e.message}"
      )
      Result.new(status: :error, error: e)
    end

    private

    attr_reader :subscription, :user, :logger, :locale

    def resumable?
      return subscription.resumable? if subscription.respond_to?(:resumable?)

      subscription.ends_at.present?
    end
  end
end
