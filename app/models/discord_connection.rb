class DiscordConnection < ApplicationRecord
  VIP_ROLE_STATES = %w[unknown pending granted removed].freeze
  SYNC_STATUSES = %w[idle queued syncing failed].freeze

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :discord_user_id,
            uniqueness: true,
            format: { with: /\A\d+\z/ },
            allow_nil: true
  validates :vip_role_state, inclusion: { in: VIP_ROLE_STATES }
  validates :sync_status, inclusion: { in: SYNC_STATUSES }
  validates :linked_at, presence: true, if: -> { discord_user_id.present? }
  validates :linked_at, absence: true, if: -> { discord_user_id.blank? }

  scope :connected, -> { where.not(discord_user_id: nil, linked_at: nil).where(disconnected_at: nil) }
  scope :disconnect_pending, -> { connected.where.not(disconnect_requested_at: nil) }
  scope :failed, -> { where(sync_status: "failed") }
  scope :reconcilable, -> { connected }

  def connected?
    discord_user_id.present? && linked_at.present? && disconnected_at.nil?
  end

  def disconnect_pending?
    connected? && disconnect_requested_at.present?
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      disconnect_requested_at
      disconnected_at
      id
      last_error_at
      last_error_code
      last_synced_at
      linked_at
      membership_pending
      sync_status
      updated_at
      user_id
      vip_role_state
    ]
  end
end
