class Licenses::CreateTrialLicensesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    Licenses::TrialProvisioner.new(user: user).call
  end
end
