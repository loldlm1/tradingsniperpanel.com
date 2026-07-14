require "rails_helper"

RSpec.describe Dashboard::DiscordPresenter do
  let(:user) { create(:user) }
  let(:configuration) do
    Struct.new(:support_url, keyword_init: true).new(support_url: "https://discord.gg/community")
  end

  before do
    allow(Discord).to receive(:enabled?).and_return(true)
    allow(Discord).to receive(:configuration).and_return(configuration)
  end

  {
    ineligible: { eligible: false },
    eligible_unlinked: { eligible: true },
    pending_join: { eligible: true, connection: { membership_pending: true, vip_role_state: "unknown" } },
    membership_screening: { eligible: true, connection: { membership_pending: true, vip_role_state: "granted" } },
    queued: { eligible: true, connection: { sync_status: "queued", vip_role_state: "unknown" } },
    granted: { eligible: true, connection: { vip_role_state: "granted" } },
    removed: { eligible: false, connection: { vip_role_state: "removed" } },
    failed: { eligible: true, connection: { sync_status: "failed" } },
    disconnecting: { eligible: true, connection: { disconnect_requested_at: Time.current } }
  }.each do |expected_state, setup|
    it "presents the #{expected_state} state" do
      create(:discord_connection, :connected, user: user, **setup.fetch(:connection, {})) if setup[:connection]

      result = described_class.new(user: user, eligibility: eligibility(setup.fetch(:eligible))).call

      expect(result.state).to eq(expected_state)
    end
  end

  it "presents the disabled state before any connection action" do
    allow(Discord).to receive(:enabled?).and_return(false)

    result = described_class.new(user: user, eligibility: eligibility(true)).call

    expect(result.state).to eq(:disabled)
    expect(result.connectable).to be(false)
  end

  it "presents checkout confirmation without granting eligibility" do
    result = described_class.new(
      user: user,
      eligibility: eligibility(false),
      checkout_pending: true
    ).call

    expect(result.state).to eq(:activation_pending)
    expect(result.eligible).to be(false)
    expect(result.connectable).to be(false)
  end

  it "exposes only a safe display label and action flags" do
    connection = create(
      :discord_connection,
      :connected,
      user: user,
      discord_username: "safe-name",
      discord_global_name: "Safe Display",
      vip_role_state: "granted"
    )

    result = described_class.new(user: user, eligibility: eligibility(true)).call

    expect(result.identity_label).to eq("Safe Display")
    expect(result.to_h.values).not_to include(connection.discord_user_id)
    expect(result.open_discord).to be(true)
    expect(result.disconnectable).to be(true)
  end

  def eligibility(eligible)
    Discord::VipEligibility::Result.new(
      eligible: eligible,
      source: eligible ? :stripe : nil,
      plan_key: eligible ? Billing::PandoraPricing::MONTHLY_KEY : nil,
      reason: eligible ? "eligible_stripe" : "no_subscription"
    )
  end
end
