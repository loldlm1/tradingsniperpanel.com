require "rails_helper"

RSpec.describe "Expert advisor bundles admin", type: :request do
  it "blocks admins from creating bundles" do
    admin = create(:user, :admin)
    expert_advisor = create(:expert_advisor)
    sign_in admin, scope: :user

    expect {
      post admin_expert_advisor_bundles_path, params: {
        expert_advisor_bundle: {
          expert_advisor_id: expert_advisor.id,
          required_addon_keys: "addon_a",
          active: true,
          sort_order: 0
        }
      }
    }.not_to change(ExpertAdvisorBundle, :count)

    expect(response).to redirect_to(admin_expert_advisor_bundles_path)
  end

  it "derives bundle_key from required add-on keys for master admins" do
    master_admin = create(:user, :master_admin)
    expert_advisor = create(:expert_advisor)
    sign_in master_admin, scope: :user

    expect {
      post admin_expert_advisor_bundles_path, params: {
        expert_advisor_bundle: {
          expert_advisor_id: expert_advisor.id,
          required_addon_keys: "addon_b, addon_a",
          active: true,
          sort_order: 0
        }
      }
    }.to change(ExpertAdvisorBundle, :count).by(1)

    bundle = ExpertAdvisorBundle.last
    expect(bundle.bundle_key).to eq("addon_a__addon_b")
  end
end
