require "openssl"

module Licenses
  class LicenseKeyEncoder
    class ConfigurationError < StandardError; end
    DEFAULT_LICENSE_DAYS = 34

    def initialize(primary_key: ENV["EA_LICENSE_PRIMARY_KEY"], secondary_key: ENV["EA_LICENSE_SECRET_KEY"])
      @primary_key = primary_key
      @secondary_key = secondary_key
    end

    def configured?
      primary_key.present? && secondary_key.present?
    end

    def generate(email:, ea_id:)
      validate_configuration!
      payload = build_payload(email:, ea_id:)
      encrypt(payload)
    end

    def decrypt(license_key)
      validate_configuration!
      decrypt_hex(license_key).delete_suffix("\x00")
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
      [email.to_s.strip.downcase, ea_id.to_s, DEFAULT_LICENSE_DAYS].join(",")
    end

    def validate_configuration!
      raise ConfigurationError, "EA license keys are not configured" unless configured?
    end

    def encrypt(plaintext)
      cipher = OpenSSL::Cipher.new("aes-256-ecb")
      cipher.encrypt
      cipher.key = cipher_key
      cipher.padding = 1
      encrypted = cipher.update(plaintext) + cipher.final
      encrypted.unpack1("H*").upcase
    end

    def decrypt_hex(hex_data)
      cipher = OpenSSL::Cipher.new("aes-256-ecb")
      cipher.decrypt
      cipher.key = cipher_key
      cipher.padding = 1
      decrypted = cipher.update([hex_data].pack("H*")) + cipher.final
      decrypted.force_encoding("UTF-8")
    end

    def cipher_key
      material = "#{secondary_key}#{primary_key}".dup
      bytes = material.encode("BINARY").bytes
      key_bytes = bytes.first(32)
      key_bytes.fill(0, key_bytes.length, 32 - key_bytes.length) if key_bytes.length < 32
      key_bytes.pack("C*")
    end

    def secure_compare(a, b)
      return false if a.blank? || b.blank?

      ActiveSupport::SecurityUtils.secure_compare(a.to_s, b.to_s)
    rescue StandardError
      false
    end
  end
end
