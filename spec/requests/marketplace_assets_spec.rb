require "rails_helper"

RSpec.describe "Marketplace assets", type: :request do
  let(:user) { create(:user) }
  let(:asset) { create(:marketplace_asset, title_en: "Risk Checklist", title_es: "Checklist de Riesgo") }
  let(:billing_plan) { create(:billing_plan, :one_time) }

  def attach_asset_file(record)
    path = Rails.root.join("spec/fixtures/files/sample_asset.pdf")
    File.open(path) do |file|
      record.file.attach(
        io: file,
        filename: "sample_asset.pdf",
        content_type: "application/pdf"
      )
    end
  end

  it "redirects unauthenticated users" do
    get dashboard_marketplace_asset_path(asset, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(new_user_session_path(locale: :en))
  end

  it "renders the asset page when access is granted (EN)" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_asset_path(asset, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include("Risk Checklist")
    expect(response.body).to include(I18n.t("dashboard.marketplace.assets.download_label", locale: :en))
  end

  it "renders the asset page when access is granted (ES)" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_asset_path(asset, locale: :es)

    expect(response).to be_successful
    expect(response.body).to include("Checklist de Riesgo")
    expect(response.body).to include(I18n.t("dashboard.marketplace.assets.download_label", locale: :es))
  end

  it "blocks access when the user did not purchase the asset" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_asset_path(asset, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(dashboard_path(locale: :en))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.assets.access_denied", locale: :en))
  end

  it "downloads the asset file when available" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)
    attach_asset_file(asset)
    sign_in user, scope: :user

    get dashboard_marketplace_asset_download_path(asset, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expected_path = Rails.application.routes.url_helpers.rails_blob_path(asset.file, disposition: "attachment", only_path: true)
    expect(location).to include(expected_path)
  end

  it "returns an alert when the asset file is missing" do
    create(:asset_plan_entitlement, marketplace_asset: asset, billing_plan: billing_plan)
    create(:marketplace_purchase, user: user, billing_plan: billing_plan)
    sign_in user, scope: :user

    get dashboard_marketplace_asset_download_path(asset, locale: :es)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include(dashboard_path(locale: :es))
    expect(flash[:alert]).to eq(I18n.t("dashboard.marketplace.assets.missing_file", locale: :es))
  end
end
