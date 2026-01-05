module Marketing
  class LandingTemplate
    DEFAULT_TEMPLATE = "neon"
    ALLOWED_TEMPLATES = %w[neon].freeze

    def self.current(env: ENV, logger: Rails.logger)
      @current ||= resolve(env: env, logger: logger)
    end

    def self.resolve(env:, logger:)
      candidate = env["LANDING_TEMPLATE"].to_s.strip
      return DEFAULT_TEMPLATE if candidate.blank?
      return candidate if ALLOWED_TEMPLATES.include?(candidate)

      logger.warn("Unknown LANDING_TEMPLATE=#{candidate.inspect}; falling back to #{DEFAULT_TEMPLATE}.")
      DEFAULT_TEMPLATE
    end

    def self.view_path(template = current)
      Rails.root.join("app/views/templates", template)
    end

    def self.reset!
      @current = nil
    end
  end
end
