require "rails_helper"

RSpec.describe "Sitemap", type: :request do
  before do
    host! "test.host"
  end

  it "renders the sitemap with public pages and locales" do
    get "/sitemap.xml"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("application/xml")
    expect(response.body).to include("http://test.host/")
    expect(response.body).to include("http://test.host/es")
    expect(response.body).to include("http://test.host/terms")
    expect(response.body).to include("http://test.host/es/terms")
    expect(response.body).to include("refunds-and-cancellations")
    expect(response.body).not_to include("/docs/")
  end
end
