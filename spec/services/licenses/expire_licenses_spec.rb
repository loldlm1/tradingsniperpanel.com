require "rails_helper"

RSpec.describe Licenses::ExpireLicenses do
  let(:now) { Time.utc(2025, 1, 10, 12, 0, 0) }

  it "marks trial and active licenses as expired when past their end time" do
    expired_trial = create(:license, status: "trial", trial_ends_at: now - 1.day)
    expired_active = create(:license, status: "active", trial_ends_at: nil, expires_at: now - 2.hours)
    active_trial = create(:license, status: "trial", trial_ends_at: now + 1.day)

    described_class.new(now: now).call

    expect(expired_trial.reload).to be_expired
    expect(expired_active.reload).to be_expired
    expect(active_trial.reload).to be_trial
  end
end
