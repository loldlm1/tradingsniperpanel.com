require "rails_helper"

RSpec.describe "Stripe webhooks", type: :request do
  it "routes the stripe webhook endpoint" do
    post "/webhooks/stripe", params: { id: "evt_test" }
    expect(response).not_to have_http_status(:not_found)
  end
end
