class DeviseMailer < Devise::Mailer
  default template_path: "devise/mailer"
  layout "mailer"

  protected

  def subject_for(key)
    I18n.t(
      :"#{devise_mapping.name}_subject",
      scope: [:devise, :mailer, key],
      default: [:subject, key.to_s.humanize],
      app_name: app_name,
      app_short_name: email_subject_brand
    )
  end

  def template_paths
    ["devise/mailer"]
  end
end
