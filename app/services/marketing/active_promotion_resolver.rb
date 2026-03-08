module Marketing
  class ActivePromotionResolver
    def call
      PromotionCode.current_active
    end
  end
end
