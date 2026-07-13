require "rails_helper"

RSpec.describe "Marketplace filters", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  {
    "tag filters" => { tags: [ "automation" ] },
    "multiple tags" => { tags: [ "automation", "manual" ] },
    "EA searches" => { q: "ea_tool", tab: "expert_advisors" },
    "course searches" => { q: "beginner", tab: "courses" }
  }.each do |label, query|
    it "redirects retired marketplace #{label} to Pandora plans" do
      get dashboard_marketplace_path(locale: :en, **query)

      expect(response).to redirect_to(dashboard_plans_path(locale: :en))
      expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.unavailable", locale: :en))
    end
  end
end
