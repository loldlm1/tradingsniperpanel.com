module Marketing
  class LandingTemplate
    DEFAULT_TEMPLATE = "neon"
    AUTH_FALLBACK_TEMPLATE = "mosaic"
    ALLOWED_TEMPLATES = %w[neon fintech].freeze
    AUTH_ACTIONS = {
      "sessions" => %w[new],
      "registrations" => %w[new],
      "passwords" => %w[new edit]
    }.freeze

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

    def self.auth_request?(controller_name:, action_name:)
      AUTH_ACTIONS.fetch(controller_name, []).include?(action_name)
    end

    def self.auth_view_paths(template: current)
      [view_path(template), view_path(AUTH_FALLBACK_TEMPLATE)].select(&:exist?)
    end

    def self.auth_template_for(controller_name:, action_name:, env: ENV, logger: Rails.logger)
      template = current(env: env, logger: logger)
      return template unless auth_request?(controller_name:, action_name:)

      auth_view_path(template, controller_name, action_name).exist? ? template : AUTH_FALLBACK_TEMPLATE
    end

    def self.auth_view_path(template, controller_name, action_name)
      Rails.root.join("app/views/templates", template, "devise", controller_name, "#{action_name}.html.erb")
    end

    def self.reset!
      @current = nil
    end
  end
end
