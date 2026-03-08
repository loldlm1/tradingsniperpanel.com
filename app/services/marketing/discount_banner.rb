module Marketing
  class DiscountBanner
    def initialize(locale: I18n.locale, resolver: ActivePromotionResolver.new)
      @locale = locale
      @resolver = resolver
    end

    def call
      promotion = resolver.call
      return unless promotion

      {
        id: promotion.id,
        code: promotion.code,
        percent: promotion.percent_off,
        title: promotion.localized_title(locale),
        body: promotion.localized_body(locale),
        cta_label: promotion.localized_cta_label(locale),
        updated_at: promotion.updated_at
      }
    end

    private

    attr_reader :locale, :resolver
  end
end
