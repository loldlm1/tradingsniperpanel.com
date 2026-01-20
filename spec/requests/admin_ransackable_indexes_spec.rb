require "rails_helper"

RSpec.describe "Admin ransackable indexes", type: :request do
  it "loads marketplace products index with ransack filters" do
    master_admin = create(:user, :master_admin)
    product = create(:marketplace_product, title_en: "Marketplace Pro")
    sign_in master_admin, scope: :user

    get admin_marketplace_products_path, params: {
      q: { title_en_cont: product.title_en }
    }

    expect(response).to have_http_status(:ok)
  end

  it "loads expert advisors index with tag filters" do
    master_admin = create(:user, :master_admin)
    tag_name = "automation"
    create(:expert_advisor, tag_list: tag_name)
    sign_in master_admin, scope: :user

    get admin_expert_advisors_path, params: {
      q: { tags_name_in: [tag_name] }
    }

    expect(response).to have_http_status(:ok)
  end

  it "loads courses index with tag filters" do
    master_admin = create(:user, :master_admin)
    tag_name = "strategy"
    create(:course, tag_list: tag_name)
    sign_in master_admin, scope: :user

    get admin_courses_path, params: {
      q: { tags_name_in: [tag_name] }
    }

    expect(response).to have_http_status(:ok)
  end

  it "loads marketplace assets index with tag filters" do
    master_admin = create(:user, :master_admin)
    tag_name = "risk"
    create(:marketplace_asset, tag_list: tag_name)
    sign_in master_admin, scope: :user

    get admin_marketplace_assets_path, params: {
      q: { tags_name_in: [tag_name] }
    }

    expect(response).to have_http_status(:ok)
  end
end
