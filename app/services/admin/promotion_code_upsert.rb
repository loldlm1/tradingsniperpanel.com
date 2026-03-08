module Admin
  class PromotionCodeUpsert
    IMMUTABLE_REMOTE_FIELDS = %i[code percent_off expires_at max_redemptions].freeze

    Result = Struct.new(:promotion_code, :errors, keyword_init: true) do
      def ok?
        errors.blank?
      end
    end

    def initialize(promotion_code: nil, attributes: {}, logger: Rails.logger)
      @promotion_code = promotion_code
      @attributes = normalize_attributes(attributes)
      @logger = logger
    end

    def call
      record = promotion_code || PromotionCode.new
      target_active = attributes.key?(:active) ? attributes[:active] : record.active?
      attrs = attributes.except(:active)
      replace_remote_objects = remote_replacement_required?(record, attrs)

      record.assign_attributes(attrs)
      record.active = false

      unless record.valid?
        return Result.new(promotion_code: record, errors: record.errors.full_messages)
      end

      record.save!

      activation = Admin::PromotionCodeActivation.new(
        promotion_code: record,
        active: target_active,
        replace_remote_objects: replace_remote_objects,
        logger: logger
      ).call

      return Result.new(promotion_code: activation.promotion_code, errors: activation.errors) unless activation.ok?

      Result.new(promotion_code: activation.promotion_code, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      record = e.record || promotion_code || PromotionCode.new
      Result.new(promotion_code: record, errors: record.errors.full_messages.presence || [e.message])
    rescue StandardError => e
      logger.error("[Admin::PromotionCodeUpsert] failed code=#{attributes[:code]}: #{e.class} - #{e.message}")
      record = promotion_code || PromotionCode.new(attributes.except(:active))
      record.errors.add(:base, e.message) if record.respond_to?(:errors)
      Result.new(promotion_code: record, errors: [e.message])
    end

    private

    attr_reader :promotion_code, :attributes, :logger

    def normalize_attributes(value)
      attrs = value.to_h.symbolize_keys
      attrs[:percent_off] = integerize(attrs[:percent_off]) if attrs.key?(:percent_off)
      attrs[:max_redemptions] = integerize(attrs[:max_redemptions]) if attrs.key?(:max_redemptions)
      attrs[:active] = ActiveModel::Type::Boolean.new.cast(attrs[:active]) if attrs.key?(:active)
      attrs[:expires_at] = parse_time(attrs[:expires_at]) if attrs.key?(:expires_at)

      attrs
    end

    def remote_replacement_required?(record, attrs)
      return true if stripe_configured? && (record.new_record? || record.stripe_coupon_id.blank? || record.stripe_promotion_code_id.blank?)
      return false unless stripe_configured?
      return false unless record.persisted?

      IMMUTABLE_REMOTE_FIELDS.any? do |field|
        attrs.key?(field) && record.public_send(field) != attrs[field]
      end
    end

    def stripe_configured?
      ENV["STRIPE_PRIVATE_KEY"].present?
    end

    def integerize(value)
      return nil if value.blank?

      value.to_i
    end

    def parse_time(value)
      return nil if value.blank?
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

      parsed = Time.zone.parse(value.to_s)
      return parsed if parsed.present?

      raise ArgumentError, I18n.t("active_admin.promotion_codes.errors.invalid_expiration")
    rescue ArgumentError, TypeError
      raise ArgumentError, I18n.t("active_admin.promotion_codes.errors.invalid_expiration")
    end
  end
end
