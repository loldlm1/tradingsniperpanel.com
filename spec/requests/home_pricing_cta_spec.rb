require "rails_helper"

RSpec.describe "Home pricing CTAs", type: :request do
  it "includes both monthly and annual price keys so selections persist" do
    get root_path

    expect(response).to have_http_status(:ok)

    %w[basic hft pro].each do |tier|
      expect(response.body).to include("#{tier}_monthly")
      expect(response.body).to include("#{tier}_annual")
    end

    expect(response.body).to include("x-bind:href")
  end
end
