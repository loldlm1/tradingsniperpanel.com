module ManualTransactions
  class Fulfillment
    def initialize(manual_transaction_id:, encoder: Licenses::LicenseKeyEncoder.new, logger: Rails.logger)
      @manual_transaction_id = manual_transaction_id
      @encoder = encoder
      @logger = logger
    end

    def call
      transaction = ManualTransaction.find_by(id: manual_transaction_id)
      return unless transaction

      plan = transaction.billing_plan
      return unless plan&.one_time?

      user = transaction.user
      return unless user.is_a?(User)

      record_marketplace_purchase(user: user, plan: plan, transaction: transaction)

      plan.expert_advisors.find_each do |expert_advisor|
        grant_license(user: user, expert_advisor: expert_advisor)
      end

      plan.courses.find_each do |course|
        grant_course_access(user: user, course: course, transaction: transaction)
      end

      mark_referral_completed(user: user)
    rescue StandardError => e
      logger.error("[ManualTransactions::Fulfillment] failed manual_transaction_id=#{manual_transaction_id}: #{e.class} - #{e.message}")
      raise
    end

    private

    attr_reader :manual_transaction_id, :encoder, :logger

    def grant_license(user:, expert_advisor:)
      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
      license.with_lock do
        return if license.access_source_one_time?

        license.access_source = "one_time"
        license.plan_interval = nil
        license.source = "manual_transaction"
        license.last_synced_at = Time.current
        license.trial_ends_at = nil
        license.expires_at = nil
        license.status = "active"
        expires_at = license.key_expires_at
        license.encrypted_key = encoder.generate(email: user.email, ea_id: expert_advisor.ea_id, expires_at: expires_at)
        license.save!
      end
    end

    def grant_course_access(user:, course:, transaction:)
      enrollment = CourseEnrollment.find_or_initialize_by(user: user, course: course)
      enrollment.access_source = "one_time"
      enrollment.purchased_at ||= transaction.paid_at
      enrollment.save!
    end

    def record_marketplace_purchase(user:, plan:, transaction:)
      product = MarketplaceProduct.find_by(billing_plan_id: plan.id)
      return unless product

      purchase = MarketplacePurchase.find_or_initialize_by(user: user, billing_plan: plan)
      return if purchase.persisted?

      purchase.purchased_at = transaction.paid_at
      purchase.save!
    end

    def mark_referral_completed(user:)
      Referrals::MarkCompleted.new(user: user).call
    rescue StandardError => e
      logger.warn("[ManualTransactions::Fulfillment] referral completion failed user_id=#{user.id}: #{e.class} - #{e.message}")
    end
  end
end
