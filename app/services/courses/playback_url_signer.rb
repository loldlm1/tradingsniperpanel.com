require "jwt"

module Courses
  class PlaybackUrlSigner
    DEFAULT_TTL = 10.minutes

    def initialize(stream_uid:, ttl: DEFAULT_TTL, signing_key: ENV["CLOUDFLARE_STREAM_SIGNING_KEY"])
      @stream_uid = stream_uid
      @ttl = ttl
      @signing_key = signing_key
    end

    def call
      return nil if stream_uid.blank? || signing_key.blank?

      token = JWT.encode({ sub: stream_uid, exp: expires_at.to_i }, signing_key, "HS256")
      "#{base_url}?token=#{token}"
    end

    private

    attr_reader :stream_uid, :ttl, :signing_key

    def base_url
      "https://videodelivery.net/#{stream_uid}/manifest/video.m3u8"
    end

    def expires_at
      ttl.from_now
    end
  end
end
