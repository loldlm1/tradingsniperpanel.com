ActiveAdmin.register DiscordConnection do
  menu label: proc { t("active_admin.discord_connections.menu") }, priority: 4

  actions :index, :show
  config.batch_actions = false

  scope :all, default: true
  scope :connected
  scope :disconnect_pending
  scope :failed

  filter :user_id
  filter :vip_role_state, as: :select, collection: DiscordConnection::VIP_ROLE_STATES
  filter :sync_status, as: :select, collection: DiscordConnection::SYNC_STATUSES
  filter :membership_pending
  filter :last_synced_at
  filter :last_error_code

  member_action :resync, method: :post do
    if Discord::SyncVipRoleJob.enqueue(resource.id)
      redirect_to resource_path(resource), notice: t("active_admin.discord_connections.resync_enqueued")
    else
      redirect_to resource_path(resource), alert: t("active_admin.discord_connections.resync_unavailable")
    end
  end

  action_item :resync, only: :show, if: proc { resource.connected? } do
    link_to t("active_admin.discord_connections.actions.resync"),
            resync_admin_discord_connection_path(resource),
            method: :post
  end

  controller do
    def scoped_collection
      super.includes(:user)
    end
  end

  index download_links: false do
    id_column
    column :user_id
    column :vip_role_state
    column :sync_status
    column :membership_pending
    column t("active_admin.discord_connections.labels.eligibility") do |connection|
      eligibility = Discord::VipEligibility.new(user: connection.user).call
      state = eligibility.eligible? ? "eligible" : "ineligible"
      "#{t("active_admin.discord_connections.states.#{state}")}:#{eligibility.reason}"
    end
    column :last_synced_at
    column :last_error_code
    column :last_error_at
    actions defaults: true do |connection|
      if connection.connected?
        item t("active_admin.discord_connections.actions.resync"),
             resync_admin_discord_connection_path(connection),
             method: :post
      end
    end
  end

  show do
    eligibility = Discord::VipEligibility.new(user: resource.user).call

    attributes_table do
      row :id
      row :user_id
      row :linked_at
      row :disconnect_requested_at
      row :disconnected_at
      row :membership_pending
      row :vip_role_state
      row :sync_status
      row :sync_started_at
      row :last_synced_at
      row :last_error_code
      row :last_error_at
      row t("active_admin.discord_connections.labels.eligibility") do
        state = eligibility.eligible? ? "eligible" : "ineligible"
        t("active_admin.discord_connections.states.#{state}")
      end
      row t("active_admin.discord_connections.labels.eligibility_source") do
        eligibility.source.presence || t("active_admin.discord_connections.states.none")
      end
      row t("active_admin.discord_connections.labels.eligibility_reason") do
        eligibility.reason
      end
      row :created_at
      row :updated_at
    end
  end
end
