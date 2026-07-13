module Licenses
  class RotateTokens
    class TokenVersionExhausted < StandardError; end
    class Unauthorized < StandardError; end
    class IdempotencyConflict < StandardError; end

    Result = Struct.new(:license_ids, :rotated_at, :audit_event, keyword_init: true) do
      def count
        license_ids.size
      end
    end

    VALID_SCOPES = %i[all user].freeze

    def initialize(scope:, actor:, request_id:, user: nil, encoder: LicenseKeyEncoder.new, now: Time.current)
      @scope = scope.to_sym
      @actor = actor
      @request_id = request_id.to_s
      @user = user
      @encoder = encoder
      @now = now
      validate_scope!
    end

    def call
      raise LicenseKeyEncoder::ConfigurationError, "EA license keys are not configured" unless encoder.configured?
      return result_from(existing_event) if existing_event

      rotated_ids, event = License.transaction do
        licenses = rotation_scope.includes(:user, :expert_advisor).reorder(:id).lock.to_a
        license_ids = licenses.map { |license| rotate!(license) }
        event = AdminAuditEvent.create!(
          actor: actor,
          action: audit_action,
          target: audit_target,
          request_id: request_id,
          metadata: {
            "affected_license_count" => license_ids.size,
            "affected_license_ids" => license_ids,
            "rotated_at" => now.iso8601(6),
            "scope" => scope.to_s,
            "user_id" => user&.id
          }.compact
        )
        [ license_ids, event ]
      end

      Result.new(license_ids: rotated_ids.freeze, rotated_at: now, audit_event: event)
    rescue ActiveRecord::RecordNotUnique
      result_from(existing_event!)
    end

    private

    attr_reader :scope, :actor, :request_id, :user, :encoder, :now

    def validate_scope!
      raise ArgumentError, "scope must be :all or :user" unless VALID_SCOPES.include?(scope)
      raise ArgumentError, "user is required for user rotation" if scope == :user && !user.is_a?(User)
      raise ArgumentError, "request_id is required" if request_id.blank? || request_id.length > 128
      raise Unauthorized, "an authorized admin is required" unless authorized_actor?
    end

    def authorized_actor?
      return false unless actor.is_a?(User) && actor.persisted?
      return actor.master_admin? if scope == :all

      actor.admin? || actor.master_admin?
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

    def audit_action
      if scope == :all
        AdminAuditEvent::ACTIONS.fetch(:all_licenses_rotated)
      else
        AdminAuditEvent::ACTIONS.fetch(:subscription_licenses_rotated)
      end
    end

    def audit_target
      user if scope == :user
    end

    def existing_event
      event = AdminAuditEvent.find_by(request_id: request_id)
      return unless event
      return event if matching_event?(event)

      raise IdempotencyConflict, "request_id was already used for another admin operation"
    end

    def existing_event!
      existing_event || raise(IdempotencyConflict, "admin operation could not be recovered")
    end

    def matching_event?(event)
      event.actor_id == actor.id &&
        event.action == audit_action &&
        event.target_type == audit_target&.class&.base_class&.name &&
        event.target_id == audit_target&.id
    end

    def result_from(event)
      ids = Array(event.metadata["affected_license_ids"]).filter_map { |id| Integer(id, exception: false) }
      rotated_at = Time.iso8601(event.metadata["rotated_at"].to_s)
      Result.new(license_ids: ids.freeze, rotated_at: rotated_at, audit_event: event)
    rescue ArgumentError
      Result.new(license_ids: ids.freeze, rotated_at: event.created_at, audit_event: event)
    end
  end
end
