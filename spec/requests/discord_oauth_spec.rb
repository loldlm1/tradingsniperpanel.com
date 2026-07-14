require "rails_helper"

RSpec.describe "Discord OAuth", type: :request do
  let(:user) { create(:user, preferred_locale: "es") }
  let(:configuration) do
    Struct.new(:client_id, :redirect_uri, :support_url, keyword_init: true).new(
      client_id: "application-id",
      redirect_uri: "https://example.com/discord/callback",
      support_url: "https://discord.gg/community"
    )
  end
  let(:eligible_result) do
    Discord::VipEligibility::Result.new(
      eligible: true,
      source: :stripe,
      plan_key: Billing::PandoraPricing::MONTHLY_KEY,
      reason: "eligible_stripe"
    )
  end

  before do
    sign_in user, scope: :user
    allow(Discord).to receive(:enabled?).and_return(true)
    allow(Discord).to receive(:configuration).and_return(configuration)
    eligibility = instance_double(Discord::VipEligibility, call: eligible_result)
    allow(Discord::VipEligibility).to receive(:new).with(user: user).and_return(eligibility)
  end

  it "uses the exact non-localized production callback route" do
    url = Rails.application.routes.url_helpers.discord_oauth_callback_url(
      host: "tradingsniperpanel.com",
      protocol: "https"
    )

    expect(url).to eq(Discord::Configuration::PRODUCTION_REDIRECT_URI)
  end

  it "starts OAuth with only identify and guilds.join plus a one-time state" do
    get authorize_dashboard_discord_connection_path(locale: :es)

    expect(response).to have_http_status(:redirect)
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)
    expect("#{uri.scheme}://#{uri.host}#{uri.path}").to eq("https://discord.com/oauth2/authorize")
    expect(query).to include(
      "client_id" => "application-id",
      "redirect_uri" => "https://example.com/discord/callback",
      "response_type" => "code",
      "scope" => "identify guilds.join"
    )
    expect(query.fetch("state")).to be_present
  end

  it "consumes state, links the current user, and returns to the preserved locale" do
    get authorize_dashboard_discord_connection_path(locale: :es)
    state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")
    result = Discord::LinkAccount::Result.new(connection: build_stubbed(:discord_connection, :connected, user: user))
    linker = instance_double(Discord::LinkAccount, call: result)
    allow(Discord::LinkAccount).to receive(:new)
      .with(user: user, code: "authorization-code")
      .and_return(linker)

    get discord_oauth_callback_path, params: { code: "authorization-code", state: state }

    expect(linker).to have_received(:call)
    expect(response).to redirect_to(dashboard_discord_connection_path(locale: :es))
    expect(flash[:notice]).to eq(I18n.t("dashboard.discord.notices.connected", locale: :es))
  end

  it "rejects state replay before another provider call" do
    get authorize_dashboard_discord_connection_path(locale: :en)
    state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")
    linker = instance_double(
      Discord::LinkAccount,
      call: Discord::LinkAccount::Result.new(connection: build_stubbed(:discord_connection, :connected, user: user))
    )
    allow(Discord::LinkAccount).to receive(:new).and_return(linker)

    get discord_oauth_callback_path, params: { code: "first-code", state: state }
    get discord_oauth_callback_path, params: { code: "replayed-code", state: state }

    expect(linker).to have_received(:call).once
    expect(flash[:alert]).to eq(I18n.t("dashboard.discord.errors.invalid_state", locale: :en))
  end

  it "handles denial and provider failure with localized recoverable messages" do
    get authorize_dashboard_discord_connection_path(locale: :es)
    denied_state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")

    get discord_oauth_callback_path, params: { error: "access_denied", state: denied_state }
    expect(flash[:alert]).to eq(I18n.t("dashboard.discord.errors.denied", locale: :es))

    get authorize_dashboard_discord_connection_path(locale: :es)
    failed_state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")
    linker = instance_double(Discord::LinkAccount)
    allow(linker).to receive(:call).and_raise(
      Discord::ForbiddenError.new(code: :forbidden, status: 403)
    )
    allow(Discord::LinkAccount).to receive(:new).and_return(linker)

    get discord_oauth_callback_path, params: { code: "sensitive-code", state: failed_state }

    expect(flash[:alert]).to eq(I18n.t("dashboard.discord.errors.provider_failed", locale: :es))
    expect(response.body).not_to include("sensitive-code", "forbidden")
  end

  it "rejects an invalid state" do
    get discord_oauth_callback_path, params: { code: "authorization-code", state: "invalid" }

    expect(response).to redirect_to(dashboard_discord_connection_path(locale: :es))
    expect(flash[:alert]).to eq(I18n.t("dashboard.discord.errors.invalid_state", locale: :es))
  end

  it "requires authentication to initiate or complete linking" do
    sign_out user

    get authorize_dashboard_discord_connection_path(locale: :en)
    expect(response).to redirect_to(new_user_session_path(locale: :en))

    get discord_oauth_callback_path, params: { code: "authorization-code", state: "state" }
    expect(response).to redirect_to(new_user_session_path)
  end
end
