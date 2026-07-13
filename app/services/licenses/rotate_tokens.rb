module Licenses
  class RotateTokens
    class TokenVersionExhausted < StandardError; end

    Result = Struct.new(:license_ids, :rotated_at, keyword_init: true) do
      def count
        license_ids.size
      end
    end

    VALID_SCOPES = %i[all user].freeze

    def initialize(scope:, user: nil, encoder: LicenseKeyEncoder.new, now: Time.current)
      @scope = scope.to_sym
      @user = user
      @encoder = encoder
      @now = now
      validate_scope!
    end

    def call
      raise LicenseKeyEncoder::ConfigurationError, "EA license keys are not configured" unless encoder.configured?

      rotated_ids = License.transaction do
        licenses = rotation_scope.includes(:user, :expert_advisor).reorder(:id).lock.to_a
        licenses.map { |license| rotate!(license) }
      end

      Result.new(license_ids: rotated_ids.freeze, rotated_at: now)
    end

    private

    attr_reader :scope, :user, :encoder, :now

    def validate_scope!
      raise ArgumentError, "scope must be :all or :user" unless VALID_SCOPES.include?(scope)
      raise ArgumentError, "user is required for user rotation" if scope == :user && !user.is_a?(User)
    end

    def rotation_scope
      base = License.active_or_trial
      return base if scope == :all

      base.where(user: user, access_source: "subscription")
    end

    def rotate!(license)
      next_version = license.token_version + 1
      raise TokenVersionExhausted, "license token version is exhausted" if next_version > License::MAX_TOKEN_VERSION

      license.assign_attributes(
        token_version: next_version,
        token_rotated_at: now,
        last_synced_at: now
      )
      license.encrypted_key = encoder.generate(**license.token_generation_attributes)
      license.save!
      license.id
    end
  end
end
