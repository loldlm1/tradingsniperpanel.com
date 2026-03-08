module Admin
  class PromotionCodeActivation
    Result = Struct.new(:promotion_code, :changed_records, :errors, keyword_init: true) do
      def ok?
        errors.blank?
      end
    end

    def initialize(promotion_code:, active:, replace_remote_objects: false, logger: Rails.logger)
      @promotion_code = promotion_code
      @active = ActiveModel::Type::Boolean.new.cast(active)
      @replace_remote_objects = replace_remote_objects
      @logger = logger
    end

    def call
      changed_records = []

      PromotionCode.transaction do
        if active
          PromotionCode.kept.where(active: true).where.not(id: promotion_code.id).lock.find_each do |other|
            next unless other.update(active: false)

            changed_records << other
          end
        end

        promotion_code.archived_at = nil if active
        promotion_code.active = active
        promotion_code.save! if promotion_code.changed?
        changed_records << promotion_code

        changed_records.each do |record|
          Billing::StripePromotionCodeSync.new(
            promotion_code: record,
            replace_remote_objects: record.id == promotion_code.id && replace_remote_objects,
            logger: logger
          ).call
        end
      end

      Result.new(promotion_code: promotion_code, changed_records: changed_records.uniq, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      record = e.record || promotion_code
      errors = record.errors.full_messages.presence || [e.message]
      Result.new(promotion_code: record, changed_records: changed_records, errors: errors)
    rescue StandardError => e
      logger.error("[Admin::PromotionCodeActivation] failed promotion_code_id=#{promotion_code&.id}: #{e.class} - #{e.message}")
      promotion_code.errors.add(:base, e.message) if promotion_code.respond_to?(:errors)
      Result.new(promotion_code: promotion_code, changed_records: changed_records, errors: [e.message])
    end

    private

    attr_reader :promotion_code, :active, :replace_remote_objects, :logger
  end
end
