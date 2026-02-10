require "rails_helper"

RSpec.describe "Seeds::Profiles" do
  before do
    load Rails.root.join("db", "seeds", "profiles.rb") unless defined?(Seeds::Profiles)
  end

  around do |example|
    original_env = ENV.to_hash
    example.run
  ensure
    ENV.replace(original_env)
  end

  it "defaults to prod_mirror in production" do
    ENV.delete("SEED_PROFILE")

    expect(Seeds::Profiles.current(environment: :production)).to eq("prod_mirror")
  end

  it "defaults to full_qa outside production" do
    ENV.delete("SEED_PROFILE")

    expect(Seeds::Profiles.current(environment: :staging)).to eq("full_qa")
    expect(Seeds::Profiles.current(environment: :development)).to eq("full_qa")
  end

  it "honors explicit overrides" do
    ENV["SEED_PROFILE"] = "prod_mirror"

    expect(Seeds::Profiles.current(environment: :staging)).to eq("prod_mirror")
  end

  it "raises for invalid overrides" do
    ENV["SEED_PROFILE"] = "invalid_profile"

    expect do
      Seeds::Profiles.current(environment: :production)
    end.to raise_error(/Invalid SEED_PROFILE/)
  end
end
