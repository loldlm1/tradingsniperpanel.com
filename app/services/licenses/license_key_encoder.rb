require "openssl"

module Licenses
  class LicenseKeyEncoder
    class ConfigurationError < StandardError; end

    def initialize(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"])
      @primary_key = primary_key
      @secondary_key = secondary_key
    end

    def generate(email:, ea_id:)
      validate_configuration!
      payload = build_payload(email:, ea_id:)
      encrypt(payload)
    end

    def valid_key?(license_key:, email:, ea_id:)
      validate_configuration!
      expected = generate(email:, ea_id:)
      secure_compare(expected, license_key)
    rescue ConfigurationError
      false
    end

    private

    attr_reader :primary_key, :secondary_key

    def build_payload(email:, ea_id:)
      [email.to_s.strip.downcase, ea_id.to_s, 0].join(",")
    end

    def validate_configuration!
      raise ConfigurationError, "EA license keys are not configured" if primary_key.blank? || secondary_key.blank?
    end

    def encrypt(plaintext)
      cipher = OpenSSL::Cipher.new("aes-256-cbc")
      cipher.encrypt
      cipher.key = cipher_key
      cipher.iv = zero_iv
      encrypted = cipher.update(plaintext) + cipher.final
      encrypted.unpack1("H*").upcase
    end

    def cipher_key
      material = "#{secondary_key}#{primary_key}".dup
      bytes = material.encode("BINARY").bytes
      key_bytes = bytes.first(32)
      key_bytes.fill(0, key_bytes.length, 32 - key_bytes.length) if key_bytes.length < 32
      key_bytes.pack("C*")
    end

    def zero_iv
      @zero_iv ||= "\x00" * 16
    end

    def secure_compare(a, b)
      return false if a.blank? || b.blank?

      ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
    rescue StandardError
      false
    end
  end
end
