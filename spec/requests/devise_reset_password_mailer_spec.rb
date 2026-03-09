require "rails_helper"

RSpec.describe "Devise reset password mailer", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:branding) { Rails.configuration.x.branding }

  def from_display_name(mail)
    Mail::Address.new(mail[:from].decoded).display_name
  end

  before do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "sends branded multipart reset instructions from support email with the configured host" do
    expect do
      perform_enqueued_jobs do
        post user_password_path, params: { user: { email: user.email } }
      end
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to eq([user.email])
    expect(mail.from).to eq([branding.support_email])
    expect(mail.reply_to).to eq([branding.support_email])
    expect(from_display_name(mail)).to eq(branding.email_display_name)
    expect(mail.subject).to eq(I18n.t("devise.mailer.reset_password_instructions.subject", app_short_name: branding.email_subject_brand))
    expect(mail).to be_multipart
    expect(mail.html_part).to be_present
    expect(mail.text_part).to be_present
    expect(mail.html_part.body.decoded).to include(I18n.t("devise.mailer.reset_password_instructions.title"))
    expect(mail.html_part.body.decoded).to include(I18n.t("mailers.shared.reply_notice", support_email: branding.support_email))
    expect(mail.text_part.body.decoded).to include(I18n.t("devise.mailer.reset_password_instructions.cta"))
    expect(mail.body.encoded).to match(%r{http://example\.com(?:/en)?/users/password/edit\?reset_password_token=})
  end
end
