require "rails_helper"

RSpec.describe "Discord connection admin", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { create(:user, :admin) }
  let(:trader) { create(:user) }
  let(:connection) do
    create(
      :discord_connection,
      :connected,
      user: trader,
      discord_username: "private-handle",
      discord_global_name: "Private Display",
      last_error_code: "forbidden"
    )
  end

  before do
    clear_enqueued_jobs
    sign_in admin, scope: :user
  end

  after do
    clear_enqueued_jobs
  end

  it "shows only safe operational connection fields" do
    connection

    get admin_discord_connections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(connection.id.to_s, trader.id.to_s, "forbidden")
    expect(response.body).not_to include(
      connection.discord_user_id,
      "private-handle",
      "Private Display"
    )
  end

  it "queues an authorized manual resync" do
    allow(Discord).to receive(:enabled?).and_return(true)

    expect do
      post resync_admin_discord_connection_path(connection)
    end.to have_enqueued_job(Discord::SyncVipRoleJob).with(connection.id)

    expect(response).to redirect_to(admin_discord_connection_path(connection))
  end

  it "keeps traders outside the admin boundary" do
    sign_out admin
    sign_in trader, scope: :user

    get admin_discord_connections_path

    expect(response).to redirect_to(root_path)
  end
end
