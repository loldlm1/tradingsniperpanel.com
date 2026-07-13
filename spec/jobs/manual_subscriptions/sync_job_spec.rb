require "rails_helper"

RSpec.describe ManualSubscriptions::SyncJob, type: :job do
  it "delegates to the race-safe manual subscription sync" do
    sync = instance_double(Licenses::ManualSubscriptionSync, call: true)
    allow(Licenses::ManualSubscriptionSync).to receive(:new)
      .with(manual_subscription_id: 123)
      .and_return(sync)

    described_class.perform_now(123)

    expect(sync).to have_received(:call)
  end
end
