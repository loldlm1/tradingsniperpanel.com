require "rails_helper"
require "base64"

RSpec.describe "Dashboard support", type: :request do
  let(:user) { create(:user, preferred_locale: "en") }

  before do
    @tempfiles = []
    sign_in user, scope: :user
  end

  after do
    @tempfiles.each(&:close!)
  end

  def uploaded_png(filename: "screenshot.png")
    tempfile = Tempfile.new([File.basename(filename, ".png"), ".png"])
    tempfile.binmode
    tempfile.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7ZxV0AAAAASUVORK5CYII="))
    tempfile.rewind
    @tempfiles << tempfile

    Rack::Test::UploadedFile.new(tempfile.path, "image/png", true, original_filename: filename)
  end

  def uploaded_text(filename: "notes.txt")
    tempfile = Tempfile.new([File.basename(filename, ".txt"), ".txt"])
    tempfile.write("not an image")
    tempfile.rewind
    @tempfiles << tempfile

    Rack::Test::UploadedFile.new(tempfile.path, "text/plain", original_filename: filename)
  end

  it "renders the support page with the current user email" do
    get dashboard_support_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(I18n.t("dashboard.support_contact", locale: :en))
    expect(response.body).to include(user.email)
    expect(response.body).to include(I18n.t("dashboard.support_screenshots", locale: :en))
  end

  it "creates a support request and enqueues the internal notification mail" do
    screenshot = uploaded_png

    expect {
      post dashboard_support_path(locale: :en), params: {
        support_request: {
          message: "Please help with billing",
          screenshots: [screenshot]
        }
      }
    }.to have_enqueued_job(SupportRequests::SendNotificationJob)

    expect(response).to redirect_to(dashboard_support_path)
    expect(flash[:notice]).to eq(I18n.t("dashboard.support_submit_success", locale: :en))

    support_request = SupportRequest.order(:created_at).last
    expect(support_request.user).to eq(user)
    expect(support_request.message).to eq("Please help with billing")
    expect(support_request.screenshots.count).to eq(1)
  end

  it "rejects non-image attachments" do
    expect {
      post dashboard_support_path(locale: :en), params: {
        support_request: {
          message: "Please help with billing",
          screenshots: [uploaded_text]
        }
      }
    }.not_to change(SupportRequest, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("dashboard.support_screenshots_type_error", locale: :en))
  end
end
