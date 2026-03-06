module Marketing
  class DiscountBanner
    MAX_PERCENT = 100

    def initialize(code: ENV["DISCOUNT_BANNER_CODE"], percent: ENV["DISCOUNT_BANNER_PERCENT"])
      @code = code.to_s.strip
      @percent = percent.to_s.strip
    end

    def call
      return if code.blank?

      normalized_percent = parse_percent(percent)
      return if normalized_percent.nil?

      {
        code: code,
        percent: normalized_percent
      }
    end

    private

    attr_reader :code, :percent

    def parse_percent(raw_value)
      cleaned = raw_value.to_s.delete("%").strip
      return if cleaned.blank?

      value = Integer(cleaned, 10)
      return if value <= 0 || value > MAX_PERCENT

      value
    rescue ArgumentError
      nil
    end
  end
end
