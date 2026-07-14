require "rails_helper"

RSpec.describe Discord::Configuration do
  let(:base_env) do
    {
      "DISCORD_INTEGRATION_ENABLED" => "true",
      "DISCORD_CLIENT_ID" => "application-id",
      "DISCORD_CLIENT_SECRET" => "client-credential",
      "DISCORD_BOT_TOKEN" => "bot-credential",
      "DISCORD_GUILD_ID" => "guild-id",
      "DISCORD_VIP_ROLE_ID" => "role-id",
      "DISCORD_REDIRECT_URI" => "https://example.com/discord/callback",
      "SUPPORT_DISCORD_URL" => "https://discord.gg/example"
    }
  end

  it "boots disabled without Discord credentials" do
    configuration = described_class.from_env({}, environment: "test")

    expect(configuration).not_to be_enabled
    expect(configuration.client_secret).to be_nil
  end

  it "normalizes surrounding whitespace without changing the callback path" do
    env = base_env.merge("DISCORD_REDIRECT_URI" => "  https://example.com/discord/callback  ")

    configuration = described_class.from_env(env, environment: "test")

    expect(configuration.redirect_uri).to eq("https://example.com/discord/callback")
  end

  it "fails closed for every missing required value without exposing configured credentials" do
    described_class::REQUIRED_ENV_KEYS.each_value do |env_key|
      expect do
        described_class.from_env(base_env.except(env_key), environment: "test")
      end.to raise_error(Discord::ConfigurationError) { |error|
        expect(error.message).to include(env_key)
        expect(error.message).not_to include("client-credential", "bot-credential")
      }
    end
  end

  it "requires the exact registered callback in production" do
    expect do
      described_class.from_env(base_env, environment: "production")
    end.to raise_error(Discord::ConfigurationError, /production DISCORD_REDIRECT_URI/)

    configuration = described_class.from_env(
      base_env.merge("DISCORD_REDIRECT_URI" => described_class::PRODUCTION_REDIRECT_URI),
      environment: "production"
    )

    expect(configuration.redirect_uri).to eq(described_class::PRODUCTION_REDIRECT_URI)
  end
end
