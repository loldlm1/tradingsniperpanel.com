class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.branding.support_email }
  layout "mailer"
end
