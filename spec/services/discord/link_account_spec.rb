require "rails_helper"

RSpec.describe Discord::LinkAccount do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:client) do
    instance_double(
      Discord::Client,
      exchange_code: {
        access_token: "short-lived-access",
        refresh_token: "discarded-refresh",
        expires_in: 3600
      },
      current_user: {
        id: "4000000000000000000",
        username: "pandora-trader",
        global_name: "Pandora Trader"
      },
      add_guild_member: Discord::Client::MemberResult.new(membership_pending: false)
    )
  end
  let(:eligibility_class) do
    eligibility = instance_double(
      Discord::VipEligibility,
      call: Discord::VipEligibility::Result.new(
        eligible: true,
        source: :stripe,
        plan_key: Billing::PandoraPricing::MONTHLY_KEY,
        reason: "eligible_stripe"
      )
    )
    class_double(Discord::VipEligibility, new: eligibility)
  end

  before do
    clear_enqueued_jobs
    allow(Discord).to receive(:enabled?).and_return(true)
  end

  after do
    clear_enqueued_jobs
  end

  it "joins the guild, persists only safe identity fields, and queues role synchronization" do
    result = described_class.new(
      user: user,
      code: "authorization-code",
      client: client,
      eligibility_class: eligibility_class
    ).call
    connection = result.connection

    expect(client).to have_received(:exchange_code).with(code: "authorization-code")
    expect(client).to have_received(:current_user).with(access_token: "short-lived-access")
    expect(client).to have_received(:add_guild_member).with(
      user_id: "4000000000000000000",
      access_token: "short-lived-access"
    )
    expect(connection).to have_attributes(
      discord_user_id: "4000000000000000000",
      discord_username: "pandora-trader",
      discord_global_name: "Pandora Trader",
      membership_pending: false,
      vip_role_state: "unknown"
    )
    expect(connection.attributes.keys).not_to include("access_token", "refresh_token")
    expect(enqueued_jobs.last.fetch(:args)).to eq([ connection.id ])
  end

  it "preserves an unknown membership-screening state for an existing guild member" do
    allow(client).to receive(:add_guild_member)
      .and_return(Discord::Client::MemberResult.new(membership_pending: nil))

    connection = described_class.new(
      user: user,
      code: "authorization-code",
      client: client,
      eligibility_class: eligibility_class
    ).call.connection

    expect(connection.membership_pending).to be_nil
  end

  it "rejects a Discord identity already owned by another Rails user" do
    create(:discord_connection, :connected, discord_user_id: "4000000000000000000")

    expect do
      described_class.new(
        user: user,
        code: "authorization-code",
        client: client,
        eligibility_class: eligibility_class
      ).call
    end.to raise_error(described_class::IdentityInUse)

    expect(user.reload.discord_connection).to be_nil
    expect(client).not_to have_received(:add_guild_member)
  end

  it "rejects account replacement until the old identity is fully unlinked" do
    create(:discord_connection, :connected, user: user, disconnect_requested_at: Time.current)

    expect do
      described_class.new(
        user: user,
        code: "authorization-code",
        client: client,
        eligibility_class: eligibility_class
      ).call
    end.to raise_error(described_class::AlreadyConnected)

    expect(client).not_to have_received(:exchange_code)
  end

  it "does not persist a connected identity when the guild join fails" do
    allow(client).to receive(:add_guild_member).and_raise(
      Discord::ForbiddenError.new(code: :forbidden, status: 403)
    )

    expect do
      described_class.new(
        user: user,
        code: "authorization-code",
        client: client,
        eligibility_class: eligibility_class
      ).call
    end.to raise_error(Discord::ForbiddenError)

    expect(user.reload.discord_connection).to be_nil
  end

  it "does not call Discord for an ineligible user" do
    ineligible = instance_double(
      Discord::VipEligibility,
      call: Discord::VipEligibility::Result.new(
        eligible: false,
        source: nil,
        plan_key: nil,
        reason: "no_subscription"
      )
    )

    expect do
      described_class.new(
        user: user,
        code: "authorization-code",
        client: client,
        eligibility_class: class_double(Discord::VipEligibility, new: ineligible)
      ).call
    end.to raise_error(described_class::Ineligible)

    expect(client).not_to have_received(:exchange_code)
  end

  it "normalizes a concurrent unique-identity conflict" do
    allow_any_instance_of(DiscordConnection).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)

    expect do
      described_class.new(
        user: user,
        code: "authorization-code",
        client: client,
        eligibility_class: eligibility_class
      ).call
    end.to raise_error(described_class::IdentityInUse)
  end
end
