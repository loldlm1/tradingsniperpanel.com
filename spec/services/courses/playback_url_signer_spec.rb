require "rails_helper"

RSpec.describe Courses::PlaybackUrlSigner do
  it "returns nil when missing stream uid" do
    url = described_class.new(stream_uid: nil, signing_key: "secret").call
    expect(url).to be_nil
  end

  it "builds a signed playback url" do
    url = described_class.new(stream_uid: "stream123", signing_key: "secret", ttl: 5.minutes).call

    expect(url).to include("https://videodelivery.net/stream123/manifest/video.m3u8")
    expect(url).to include("token=")
  end
end
