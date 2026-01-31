require "rails_helper"

RSpec.describe "Robots", type: :request do
  before do
    host! "test.host"
  end

  it "renders robots with sitemap" do
    get "/robots.txt"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("text/plain")
    expect(response.body).to include("Sitemap: http://test.host/sitemap.xml")
    expect(response.body).to include("Disallow: /dashboard")
  end
end
