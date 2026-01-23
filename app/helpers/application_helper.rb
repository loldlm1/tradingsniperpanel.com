module ApplicationHelper
  include Pagy::Frontend
  def support_email
    Rails.configuration.x.branding.support_email
  end

  def app_name
    Rails.configuration.x.branding.app_name
  end

  def app_short_name
    Rails.configuration.x.branding.short_name
  end

  def marketing_assets_template
    Marketing::LandingTemplate.auth_template_for(controller_name: controller_name, action_name: action_name)
  end

  def locale_link_class(locale)
    base = "px-2 py-1 rounded-full text-xs font-semibold transition"
    I18n.locale.to_s == locale.to_s ? "#{base} bg-blue-500 text-white" : "#{base} text-gray-300 hover:text-white bg-gray-800/60"
  end

  def landing_logo_path
    template = Marketing::LandingTemplate.current
    case template
    when "neon"
      "neon/images/logo_snipe_oficial.png"
    else
      "/docs/sniper_advanced_panel/Dark_SAP_logo.png"
    end
  end

  def landing_logo_alt
    template = Marketing::LandingTemplate.current
    I18n.t("landing.#{template}.brand.logo_alt", default: app_name)
  end

  def format_duration(seconds)
    total = seconds.to_i
    return "0:00" if total <= 0

    minutes, secs = total.divmod(60)
    hours, minutes = minutes.divmod(60)

    if hours.positive?
      format("%d:%02d:%02d", hours, minutes, secs)
    else
      format("%d:%02d", minutes, secs)
    end
  end

  def loading_label(label, loading_text: t("loading.default", default: "Processing..."))
    content_tag(:span, label, data: { loading_label: true }) +
      content_tag(:span, class: "inline-flex items-center justify-center gap-2", data: { loading_spinner: true }, role: "status", "aria-live": "polite", hidden: true) do
        spinner_circle = content_tag(:span, "", class: "loading-spinner inline-block h-4 w-4 rounded-full border-2 border-solid border-current border-t-transparent align-middle", style: "border-color: currentColor; border-top-color: transparent;")
        concat(spinner_circle)
        concat(content_tag(:span, loading_text, class: "text-sm"))
      end
  end
end
