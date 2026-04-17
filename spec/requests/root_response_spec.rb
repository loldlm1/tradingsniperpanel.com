require "rails_helper"

RSpec.describe "Root response contract", type: :request do
  around do |example|
    original_template = ENV["LANDING_TEMPLATE"]
    ENV["LANDING_TEMPLATE"] = "neon"
    Marketing::LandingTemplate.reset!
    example.run
  ensure
    ENV["LANDING_TEMPLATE"] = original_template
    Marketing::LandingTemplate.reset!
  end

  it "returns HTML for generic accept headers and includes the Meta verification tag" do
    get root_path, headers: { "ACCEPT" => "*/*" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include('meta name="facebook-domain-verification" content="x5hxl2xzp1jt7ocwq5nsi0xpf8or4r"')
  end

  it "keeps HTML responses working for explicit text/html requests" do
    get root_path, headers: { "ACCEPT" => "text/html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include('meta name="facebook-domain-verification" content="x5hxl2xzp1jt7ocwq5nsi0xpf8or4r"')
  end
end
