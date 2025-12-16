require "rails_helper"

RSpec.describe LocaleResolver do
  let(:session) { {} }
  let(:params) { {} }
  let(:logger) { instance_double(Logger, debug: nil) }

  def build_request(remote_ip: "127.0.0.1", accept_language: nil)
    env = {}
    env["HTTP_ACCEPT_LANGUAGE"] = accept_language if accept_language
    instance_double(ActionDispatch::Request, remote_ip:, env:)
  end

  describe "#resolved_locale" do
    it "prefers locale param" do
      resolver = described_class.new(
        params: { locale: "es" },
        session:,
        request: build_request,
        user: nil
      )

      expect(resolver.resolved_locale).to eq("es")
    end

    it "uses session locale when no param" do
      resolver = described_class.new(
        params:,
        session: { locale: :es },
        request: build_request,
        user: nil
      )

      expect(resolver.resolved_locale).to eq("es")
    end

    it "falls back to user preferred locale" do
      user = build_stubbed(:user, preferred_locale: "es")
      resolver = described_class.new(
        params:,
        session:,
        request: build_request,
        user:
      )

      expect(resolver.resolved_locale).to eq("es")
    end

    it "uses Accept-Language header when nothing else is present" do
      resolver = described_class.new(
        params:,
        session:,
        request: build_request(accept_language: "es-ES,es;q=0.9,en;q=0.8"),
        user: nil
      )

      expect(resolver.resolved_locale).to eq("es")
    end

    it "returns default locale when no signals found" do
      resolver = described_class.new(
        params:,
        session:,
        request: build_request,
        user: nil
      )

      expect(resolver.resolved_locale).to eq(I18n.default_locale.to_s)
    end

    it "uses GeoIP when IP is public and database responds" do
      db_path = Rails.root.join("tmp/GeoLite2-City.mmdb").to_s
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(db_path).and_return(true)

      country = double("Country", iso_code: "ES")
      result = double("GeoResult", country:)
      maxmind = double("MaxMindDB", lookup: result)
      allow(MaxMindDB).to receive(:new).with(db_path).and_return(maxmind)

      original = ENV["MAXMIND_DB_PATH"]
      ENV["MAXMIND_DB_PATH"] = db_path

      resolver = described_class.new(
        params:,
        session:,
        request: build_request(remote_ip: "8.8.8.8"),
        user: nil
      )

      expect(resolver.resolved_locale).to eq("es")
    ensure
      ENV["MAXMIND_DB_PATH"] = original
    end

    it "logs and ignores GeoIP errors" do
      db_path = Rails.root.join("tmp/GeoLite2-City.mmdb").to_s
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(db_path).and_return(true)
      allow(MaxMindDB).to receive(:new).and_raise(StandardError.new("lookup failed"))

      original = ENV["MAXMIND_DB_PATH"]
      ENV["MAXMIND_DB_PATH"] = db_path

      messages = []
      allow(logger).to receive(:debug) { |&blk| messages << blk.call if blk }

      resolver = described_class.new(
        params:,
        session:,
        request: build_request(remote_ip: "8.8.8.8"),
        user: nil,
        logger:
      )

      expect(resolver.resolved_locale).to eq(I18n.default_locale.to_s)
      expect(messages.join).to include("GeoIP lookup failed")
    ensure
      ENV["MAXMIND_DB_PATH"] = original
    end
  end

  describe "#persist_user_locale?" do
    it "returns false when there is no user" do
      resolver = described_class.new(
        params:,
        session:,
        request: build_request,
        user: nil
      )

      expect(resolver.persist_user_locale?).to be(false)
    end

    it "returns true when the locale changed for the user" do
      user = build_stubbed(:user, preferred_locale: "en")
      resolver = described_class.new(
        params: { locale: "es" },
        session:,
        request: build_request,
        user:
      )

      expect(resolver.persist_user_locale?).to be(true)
    end

    it "returns false when the locale matches the user preference" do
      user = build_stubbed(:user, preferred_locale: "es")
      resolver = described_class.new(
        params: { locale: "es" },
        session:,
        request: build_request,
        user:
      )

      expect(resolver.persist_user_locale?).to be(false)
    end
  end
end
