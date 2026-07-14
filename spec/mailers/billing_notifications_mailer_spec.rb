require "rails_helper"

RSpec.describe BillingNotificationsMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:branding) { Rails.configuration.x.branding }

  def from_display_name(mail)
    Mail::Address.new(mail[:from].decoded).display_name
  end

  it "uses the branded sender and renders a multipart subscription email" do
    allow(Discord).to receive(:enabled?).and_return(false)
    email = described_class.with(
      user: user,
      plan_name: "Basic Monthly",
      amount_cents: 1_000,
      currency: "usd",
      invoice_id: "in_test",
      invoice_url: nil
    ).subscription_started

    expect(email.from).to eq([ branding.support_email ])
    expect(email.reply_to).to eq([ branding.support_email ])
    expect(from_display_name(email)).to eq(branding.email_display_name)
    expect(email.subject).to eq(I18n.t("billing_mailer.subscription_started.subject", app_short_name: branding.email_subject_brand))
    expect(email).to be_multipart
    expect(email.html_part.body.decoded).to include(I18n.t("billing_mailer.subscription_started.title"))
    expect(email.html_part.body.decoded).to include("Basic Monthly")
    expect(email.text_part.body.decoded).to include(I18n.t("billing_mailer.subscription_started.billing_cta"))
  end

  it "uses localized Discord activation as the primary CTA when enabled" do
    allow(Discord).to receive(:enabled?).and_return(true)

    I18n.with_locale(:es) do
      email = described_class.with(
        user: user,
        plan_name: "Pandora Box",
        amount_cents: Billing::PandoraPricing::MONTHLY_CENTS,
        currency: "usd",
        invoice_id: "in_discord",
        invoice_url: "https://example.com/invoice"
      ).subscription_started
      html = email.html_part.body.decoded
      text = email.text_part.body.decoded

      expect(html).to include(
        I18n.t("billing_mailer.subscription_started.discord_cta"),
        dashboard_discord_connection_url(locale: :es),
        "https://example.com/invoice"
      )
      expect(text).to include(
        I18n.t("billing_mailer.subscription_started.discord_cta"),
        dashboard_discord_connection_url(locale: :es),
        I18n.t("billing_mailer.invoice_cta")
      )
      expect("#{html}\n#{text}").not_to include("discord_user_id", "oauth_state", "DISCORD_BOT_TOKEN")
    end
  end

  it "renders a localized one-time purchase confirmation in spanish" do
    I18n.with_locale(:es) do
      email = described_class.with(
        user: user,
        plan_names: [ "Alpha Pack", "Beta Pack" ],
        amount_cents: 2_500,
        currency: "usd",
        charge_id: "ch_test",
        receipt_url: "https://example.com/receipt"
      ).one_time_purchase_confirmed

      expect(email.subject).to eq(I18n.t("billing_mailer.one_time_purchase_confirmed.subject", app_short_name: branding.email_subject_brand))
      expect(email.html_part.body.decoded).to include(I18n.t("billing_mailer.one_time_purchase_confirmed.title"))
      expect(email.html_part.body.decoded).to include("Alpha Pack")
      expect(email.text_part.body.decoded).to include(I18n.t("billing_mailer.receipt_cta"))
    end
  end
end
