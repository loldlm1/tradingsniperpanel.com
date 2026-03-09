require "rails_helper"

RSpec.describe DeviseMailer, type: :mailer do
  let(:user) { create(:user, email: "mailer-user@example.com") }
  let(:branding) { Rails.configuration.x.branding }

  before do
    Rails.application.reload_routes!
  end

  def from_display_name(mail)
    Mail::Address.new(mail[:from].decoded).display_name
  end

  it "renders a branded password change email" do
    mail = described_class.password_change(user)

    expect(mail.from).to eq([branding.support_email])
    expect(mail.reply_to).to eq([branding.support_email])
    expect(from_display_name(mail)).to eq(branding.email_display_name)
    expect(mail.subject).to eq(I18n.t("devise.mailer.password_change.subject", app_short_name: branding.email_subject_brand))
    expect(mail).to be_multipart
    expect(mail.html_part.body.decoded).to include(I18n.t("devise.mailer.password_change.title"))
    expect(mail.html_part.body.decoded).to include(I18n.t("mailers.shared.categories.account_security"))
    expect(mail.text_part.body.decoded).to include(I18n.t("devise.mailer.password_change.notice"))
  end

  it "renders localized reset password instructions in spanish" do
    I18n.with_locale(:es) do
      mail = described_class.reset_password_instructions(user, "reset-token-123")

      expect(mail.subject).to eq(I18n.t("devise.mailer.reset_password_instructions.subject", app_short_name: branding.email_subject_brand))
      expect(mail.html_part.body.decoded).to include(I18n.t("devise.mailer.reset_password_instructions.title"))
      expect(mail.html_part.body.decoded).to include(I18n.t("mailers.shared.reply_notice", support_email: branding.support_email))
      expect(mail.text_part.body.decoded).to include("reset-token-123")
    end
  end
end
