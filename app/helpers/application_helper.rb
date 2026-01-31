module ApplicationHelper
  def support_email
    Rails.configuration.x.branding.support_email
  end

  def support_phone
    Rails.configuration.x.branding.support_phone
  end

  def support_chat_url
    Rails.configuration.x.branding.support_chat_url
  end

  def support_discord_url
    Rails.configuration.x.branding.support_discord_url
  end

  def support_telegram_url
    Rails.configuration.x.branding.support_telegram_url
  end

  def support_contact_links
    links = []
    links << { label: support_email, url: "mailto:#{support_email}" } if support_email.present?
    links << { label: support_phone, url: "tel:#{support_phone}" } if support_phone.present?
    links << { label: t("footer.contact.chat"), url: support_chat_url } if support_chat_url.present?
    links << { label: t("footer.contact.discord"), url: support_discord_url } if support_discord_url.present?
    links << { label: t("footer.contact.telegram"), url: support_telegram_url } if support_telegram_url.present?
    links
  end

  def app_name
    Rails.configuration.x.branding.app_name
  end

  def app_short_name
    Rails.configuration.x.branding.short_name
  end

  def brand_legal_name
    Rails.configuration.x.branding.brand_legal_name
  end

  def brand_trade_name
    Rails.configuration.x.branding.brand_trade_name
  end

  def brand_display_name
    return app_name if brand_legal_name.blank? && brand_trade_name.blank?
    return brand_legal_name if brand_trade_name.blank?
    return brand_trade_name if brand_legal_name.blank?

    "#{brand_legal_name} (#{brand_trade_name})"
  end

  def brand_address_parts
    address = Rails.configuration.x.branding.brand_address || {}
    [
      address[:line1],
      address[:line2],
      address[:city],
      address[:state],
      address[:postal],
      address[:country]
    ].compact_blank
  end

  def brand_full_address
    brand_address_parts.join(", ")
  end

  def legal_sections(key)
    interpolations = {
      support_email: support_email,
      brand_legal_name: brand_legal_name,
      brand_trade_name: brand_trade_name,
      brand_display_name: brand_display_name,
      brand_address: brand_full_address
    }
    sections = Array(I18n.t("legal.#{key}.sections", default: []))
    sections.map { |section| interpolate_legal_content(section, interpolations) }
  end

  def interpolate_legal_content(value, interpolations)
    case value
    when String
      I18n.interpolate(value, interpolations)
    when Array
      value.map { |item| interpolate_legal_content(item, interpolations) }
    when Hash
      value.to_h.transform_values { |item| interpolate_legal_content(item, interpolations) }
    else
      value
    end
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
      "neon/images/logo_oficial.png"
    else
      "/docs/sniper_advanced_panel/Dark_SAP_logo.png"
    end
  end

  def landing_logo_alt
    template = Marketing::LandingTemplate.current
    I18n.t("landing.#{template}.brand.logo_alt", default: app_name)
  end

  def landing_favicon_href
    template = Marketing::LandingTemplate.current
    case template
    when "neon"
      image_path("neon/images/logo_oficial.png")
    else
      "/icon.png"
    end
  end

  def landing_favicon_svg_href
    template = Marketing::LandingTemplate.current
    return nil if template == "neon"

    "/icon.svg"
  end

  def seo_title
    raw_title = content_for?(:title) ? content_for(:title) : app_name
    strip_tags(raw_title.to_s).squish
  end

  def seo_description
    raw_description = content_for?(:meta_description) ? content_for(:meta_description) : I18n.t("app.tagline", default: app_name)
    strip_tags(raw_description.to_s).squish
  end

  def seo_canonical_url
    return content_for(:canonical_url).to_s if content_for?(:canonical_url)

    "#{request.base_url}#{request.path}"
  end

  def seo_image_path
    return content_for(:meta_image).to_s if content_for?(:meta_image)

    landing_favicon_href
  end

  def seo_image_url
    path = seo_image_path
    return "" if path.blank?
    return path if path.start_with?("http://", "https://")

    "#{request.base_url}#{path}"
  end

  def seo_robots
    return "noindex, nofollow" if devise_controller?

    "index, follow"
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
