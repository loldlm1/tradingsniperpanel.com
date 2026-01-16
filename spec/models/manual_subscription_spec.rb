require "rails_helper"

RSpec.describe ManualSubscription, type: :model do
  it "is valid with a subscription billing plan" do
    subscription = build(:manual_subscription)
    expect(subscription).to be_valid
  end

  it "rejects one-time billing plans" do
    subscription = build(:manual_subscription, billing_plan: create(:billing_plan, :one_time))
    expect(subscription).not_to be_valid
  end

  it "requires ends_at after starts_at" do
    subscription = build(:manual_subscription, starts_at: Time.current, ends_at: 1.day.ago)
    expect(subscription).not_to be_valid
  end

  it "scopes active subscriptions for a given time" do
    active = create(:manual_subscription, starts_at: 2.days.ago, ends_at: 2.days.from_now)
    inactive = create(:manual_subscription, starts_at: 10.days.ago, ends_at: 5.days.ago)

    expect(described_class.active_at(Time.current)).to include(active)
    expect(described_class.active_at(Time.current)).not_to include(inactive)
  end
end
