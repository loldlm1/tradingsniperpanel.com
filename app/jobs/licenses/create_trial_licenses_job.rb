class Licenses::CreateTrialLicensesJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    encoder = Licenses::LicenseKeyEncoder.new
    unless encoder.configured?
      Rails.logger.warn("Licenses::CreateTrialLicensesJob skipped: license keys not configured")
      return
    end

    Licenses::TrialProvisioner.new(user: user, encoder: encoder).call
  end
end
