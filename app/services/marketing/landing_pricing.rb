module Marketing
  class LandingPricing
    def initialize(template: LandingTemplate.current)
      @template = template
    end

    def call
      case @template
      when "neon"
        NeonLandingPricing.new.call
      else
        {}
      end
    end
  end
end
