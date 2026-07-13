class AdminAuditEvent < ApplicationRecord
  ACTIONS = {
    manual_subscription_granted: "manual_subscription.granted",
    manual_subscription_revoked: "manual_subscription.revoked",
    subscription_licenses_rotated: "licenses.subscription_rotated",
    all_licenses_rotated: "licenses.all_rotated"
  }.freeze
  SENSITIVE_METADATA_KEYS = %w[
    encrypted_key
    license_key
    token
    raw_token
    previous_key
    previous_token
    decrypted_payload
    cipher_key
    raw_stripe_object
    stripe_object
    stripe_event
    processor_payload
    raw_processor_payload
  ].freeze

  belongs_to :actor, class_name: "User"
  belongs_to :target, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS.values }
  validates :request_id, presence: true, length: { maximum: 128 }, uniqueness: true
  validate :metadata_is_safe_object
  validate :target_matches_action

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  private

  def metadata_is_safe_object
    unless metadata.is_a?(Hash)
      errors.add(:metadata, :invalid)
      return
    end

    errors.add(:metadata, :invalid) if sensitive_metadata_key?(metadata)
  end

  def sensitive_metadata_key?(value)
    case value
    when Hash
      value.any? do |key, nested_value|
        SENSITIVE_METADATA_KEYS.include?(key.to_s.downcase) || sensitive_metadata_key?(nested_value)
      end
    when Array
      value.any? { |nested_value| sensitive_metadata_key?(nested_value) }
    else
      false
    end
  end

  def target_matches_action
    if action == ACTIONS.fetch(:all_licenses_rotated)
      errors.add(:target, :invalid) if target.present?
    elsif ACTIONS.value?(action)
      errors.add(:target, :invalid) unless target.is_a?(User)
    end
  end
end
