require "rails_helper"

RSpec.describe "Deprecated marketing routes", type: :request do
  it "returns 404 for pricing and docs" do
    get "/pricing"
    expect(response).to have_http_status(:not_found)

    get "/docs"
    expect(response).to have_http_status(:not_found)
  end
end
