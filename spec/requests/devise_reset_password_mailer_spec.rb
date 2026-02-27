require "rails_helper"

RSpec.describe "Devise reset password mailer", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "sends reset instructions from support email with the configured host" do
    expect do
      perform_enqueued_jobs do
        post user_password_path, params: { user: { email: user.email } }
      end
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to eq([user.email])
    expect(mail.from).to eq([Rails.configuration.x.branding.support_email])
    expect(mail.body.encoded).to match(%r{http://example\.com(?:/en)?/users/password/edit\?reset_password_token=})
  end
end
