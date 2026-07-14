require "rails_helper"

RSpec.describe Discord::OauthState do
  Clock = Struct.new(:now)

  let(:session) { {} }
  let(:clock) { Clock.new(Time.utc(2026, 7, 14, 12)) }
  let(:random) { class_double(SecureRandom, urlsafe_base64: "one-time-state") }
  let(:service) { described_class.new(session: session, clock: clock, random: random) }

  it "stores a digest and returns locale plus the fixed internal target once" do
    state = service.issue(locale: :es)

    expect(state).to eq("one-time-state")
    expect(session.dig(described_class::SESSION_KEY, "digest")).not_to eq(state)

    payload = service.consume(state)
    expect(payload).to have_attributes(
      locale: "es",
      return_target: described_class::RETURN_TARGET
    )
    expect(session).not_to have_key(described_class::SESSION_KEY)
  end

  it "cannot be replayed" do
    state = service.issue(locale: :en)
    service.consume(state)

    expect { service.consume(state) }.to raise_error(described_class::InvalidState)
  end

  it "rejects a mismatched state and consumes the stored value" do
    service.issue(locale: :en)

    expect { service.consume("different-state") }.to raise_error(described_class::InvalidState)
    expect(session).not_to have_key(described_class::SESSION_KEY)
  end

  it "expires the state after ten minutes" do
    state = service.issue(locale: :en)
    clock.now += 11.minutes

    expect { service.consume(state) }.to raise_error(described_class::ExpiredState)
  end

  it "rejects unsupported locales and return targets" do
    expect { service.issue(locale: :fr) }.to raise_error(ArgumentError, /locale/)
    expect do
      service.issue(locale: :en, return_target: "https://example.net")
    end.to raise_error(ArgumentError, /return target/)
  end
end
