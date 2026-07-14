require "rails_helper"

RSpec.describe Discord::Client do
  Configuration = Struct.new(
    :client_id,
    :client_secret,
    :bot_token,
    :guild_id,
    :vip_role_id,
    :redirect_uri,
    keyword_init: true
  )

  class FakeTransport
    attr_reader :requests

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
      @requests = []
    end

    def call(**request)
      requests << request
      raise error if error

      response
    end

    private

    attr_reader :response, :error
  end

  let(:configuration) do
    Configuration.new(
      client_id: "application-id",
      client_secret: "client-credential",
      bot_token: "bot-credential",
      guild_id: "guild-id",
      vip_role_id: "role-id",
      redirect_uri: "https://example.com/discord/callback"
    )
  end
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }

  it "exchanges an authorization code with form encoding" do
    transport = fake_transport(
      status: 200,
      body: JSON.generate(
        access_token: "oauth-access",
        refresh_token: "oauth-refresh",
        token_type: "Bearer",
        expires_in: 3600,
        scope: "identify guilds.join"
      )
    )
    client = build_client(transport)

    result = client.exchange_code(code: "authorization-code")
    request = transport.requests.fetch(0)

    expect(result).to include(access_token: "oauth-access", refresh_token: "oauth-refresh", expires_in: 3600)
    expect(request[:method]).to eq(:post)
    expect(request[:uri].path).to eq("/api/v10/oauth2/token")
    expect(request[:headers]).to eq("Content-Type" => "application/x-www-form-urlencoded")
    expect(URI.decode_www_form(request[:body]).to_h).to include(
      "client_id" => "application-id",
      "client_secret" => "client-credential",
      "grant_type" => "authorization_code",
      "code" => "authorization-code",
      "redirect_uri" => "https://example.com/discord/callback"
    )
  end

  it "loads the current identity with Bearer authorization" do
    transport = fake_transport(
      status: 200,
      body: JSON.generate(id: "1000000000000000000", username: "trader", global_name: "Pandora Trader")
    )

    result = build_client(transport).current_user(access_token: "oauth-access")
    request = transport.requests.fetch(0)

    expect(result).to eq(
      id: "1000000000000000000",
      username: "trader",
      global_name: "Pandora Trader"
    )
    expect(request[:headers]).to eq("Authorization" => "Bearer oauth-access")
  end

  it "adds a guild member and preserves membership screening state" do
    transport = fake_transport(status: 201, body: JSON.generate(pending: true))

    result = build_client(transport).add_guild_member(
      user_id: "1000000000000000000",
      access_token: "oauth-access"
    )
    request = transport.requests.fetch(0)

    expect(result.membership_pending).to be(true)
    expect(request[:method]).to eq(:put)
    expect(request[:uri].path).to eq("/api/v10/guilds/guild-id/members/1000000000000000000")
    expect(request[:headers]["Authorization"]).to eq("Bot bot-credential")
    expect(JSON.parse(request[:body])).to eq("access_token" => "oauth-access")
  end

  it "treats an existing guild member response as successful" do
    transport = fake_transport(status: 204)

    result = build_client(transport).add_guild_member(
      user_id: "1000000000000000000",
      access_token: "oauth-access"
    )

    expect(result.membership_pending).to be_nil
  end

  it "adds and removes only the configured VIP role" do
    add_transport = fake_transport(status: 204)
    remove_transport = fake_transport(status: 204)

    expect(build_client(add_transport).add_vip_role(user_id: "1000000000000000000")).to be(true)
    expect(build_client(remove_transport).remove_vip_role(user_id: "1000000000000000000")).to be(true)
    expect(add_transport.requests.fetch(0)[:uri].path).to end_with(
      "/guilds/guild-id/members/1000000000000000000/roles/role-id"
    )
    expect(remove_transport.requests.fetch(0)[:method]).to eq(:delete)
  end

  it "treats an absent member or role as an idempotent removal" do
    transport = fake_transport(status: 404, body: JSON.generate(message: "Unknown Member"))

    expect(build_client(transport).remove_vip_role(user_id: "1000000000000000000")).to be(true)
  end

  {
    401 => Discord::UnauthorizedError,
    403 => Discord::ForbiddenError,
    404 => Discord::NotFoundError,
    500 => Discord::ServerError
  }.each do |status, error_class|
    it "normalizes HTTP #{status} without exposing the response body" do
      transport = fake_transport(status: status, body: "sensitive-provider-response")

      expect do
        build_client(transport).current_user(access_token: "oauth-access")
      end.to raise_error(error_class) { |error|
        expect(error.message).not_to include("sensitive-provider-response", "oauth-access")
        expect(error.status).to eq(status)
      }
    end
  end

  it "preserves Discord Retry-After as structured data" do
    transport = fake_transport(
      status: 429,
      headers: { "retry-after" => "2.5" },
      body: JSON.generate(retry_after: 2.5)
    )

    expect do
      build_client(transport).add_vip_role(user_id: "1000000000000000000")
    end.to raise_error(Discord::RateLimitedError) { |error|
      expect(error.retry_after).to eq(2.5)
    }
  end

  it "normalizes transport timeouts" do
    transport = FakeTransport.new(error: Timeout::Error.new)

    expect do
      build_client(transport).current_user(access_token: "oauth-access")
    end.to raise_error(Discord::TransportError)
  end

  it "rejects malformed successful JSON" do
    transport = fake_transport(status: 200, body: "not-json")

    expect do
      build_client(transport).current_user(access_token: "oauth-access")
    end.to raise_error(Discord::InvalidResponseError)
  end

  def fake_transport(status:, headers: {}, body: "")
    FakeTransport.new(response: Discord::Client::Response.new(status: status, headers: headers, body: body))
  end

  def build_client(transport)
    described_class.new(
      configuration: configuration,
      transport: transport,
      clock: Time,
      logger: logger
    )
  end
end
