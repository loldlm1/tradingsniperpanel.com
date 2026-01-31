class SitemapsController < ApplicationController
  layout false

  def show
    @urls = build_urls
    response.headers["Content-Type"] = "application/xml"
  end

  def robots
    sitemap_url = "#{request.base_url}/sitemap.xml"
    body = <<~ROBOTS
      User-agent: *
      Disallow: /dashboard
      Disallow: /users
      Disallow: /admin
      Disallow: /terms_acceptance
      Allow: /
      Sitemap: #{sitemap_url}
    ROBOTS
    render plain: body
  end

  private

  def build_urls
    locales = I18n.available_locales
    default_locale = I18n.default_locale
    routes = [
      :root_path,
      :terms_path,
      :privacy_path,
      :refunds_and_cancellations_path
    ]

    routes.flat_map do |path_helper|
      locales.map do |locale|
        path = localized_path(path_helper, locale, default_locale)
        {
          path: path,
          locale: locale,
          alternates: alternates_for(path_helper, locales, default_locale)
        }
      end
    end
  end

  def alternates_for(path_helper, locales, default_locale)
    locales.map do |locale|
      {
        locale: locale,
        path: localized_path(path_helper, locale, default_locale),
        default: locale == default_locale
      }
    end
  end

  def localized_path(path_helper, locale, default_locale)
    if locale == default_locale
      public_send(path_helper)
    else
      public_send(path_helper, locale: locale)
    end
  end
end
