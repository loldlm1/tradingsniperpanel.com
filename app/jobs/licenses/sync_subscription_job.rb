class Licenses::SyncSubscriptionJob < ApplicationJob
  queue_as :default

  def perform(subscription_id)
    Licenses::SubscriptionLicenseSync.new(subscription_id: subscription_id).call
  end
end
