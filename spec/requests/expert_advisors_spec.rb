require "rails_helper"

RSpec.describe "Expert advisor guides", type: :request do
  let(:user) { create(:user) }
  let(:expert_advisor) do
    create(:expert_advisor, doc_guide_en: "# Sniper Advanced Panel\n\nFirst paragraph.")
  end
  let(:bundle_path) { Rails.root.join("spec/fixtures/files/ea_bundle.rar") }

  def attach_bundle(record)
    File.open(bundle_path) do |file|
      record.ea_files.attach(
        io: file,
        filename: "ea_bundle.rar",
        content_type: "application/x-rar-compressed"
      )
    end
  end

  def attach_ea_bundle(bundle, filename:)
    File.open(bundle_path) do |file|
      bundle.bundle_file.attach(
        io: file,
        filename: filename,
        content_type: "application/x-rar-compressed"
      )
    end
  end

  it "renders the Expert Advisors index page with guide preview" do
    create(:user_expert_advisor, user:, expert_advisor:)
    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("Sniper Advanced Panel")
    expect(response.body).to include("First paragraph.")
  end

  it "renders guides for an active user EA" do
    create(:user_expert_advisor, user:, expert_advisor:)
    sign_in user, scope: :user

    get dashboard_expert_advisor_guides_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("Sniper Advanced Panel")
  end

  it "renders the EA show page for a locked user" do
    sign_in user, scope: :user

    get dashboard_expert_advisor_path(expert_advisor, locale: :en)

    expect(response).to be_successful
    expect(response.body).to include(expert_advisor.name)
    expect(response.body).to include("Sniper Advanced Panel")
  end

  it "returns not found when user does not own the EA" do
    sign_in user, scope: :user

    get dashboard_expert_advisor_guides_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:not_found)
  end

  it "redirects to the bundle download when licensed" do
    create(:license, user:, expert_advisor:)
    attach_bundle(expert_advisor)
    sign_in user, scope: :user

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expect(location).to include("/#{expert_advisor.ea_id}.rar")
    expect(location).not_to include("ea_bundle")
  end

  it "redirects to the matching expert advisor bundle when bundles exist" do
    create(:license, user:, expert_advisor:)
    bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    attach_ea_bundle(bundle, filename: "#{expert_advisor.ea_id}__base.rar")
    sign_in user, scope: :user

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    expect(location).to include("/rails/active_storage/blobs/")
    expect(location).to include("#{expert_advisor.ea_id}__base.rar")
  end

  it "blocks bundle downloads when the matching bundle is missing" do
    create(:license, user:, expert_advisor:)
    create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    sign_in user, scope: :user

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/expert_advisors")
    expect(flash[:alert]).to eq(I18n.t("dashboard.expert_advisors.bundle_missing"))
  end

  it "blocks bundle download when locked" do
    attach_bundle(expert_advisor)
    sign_in user, scope: :user

    get dashboard_expert_advisor_download_path(expert_advisor, locale: :en)

    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to include("/dashboard/expert_advisors")
  end

  it "orders expert advisors by tier_rank then name" do
    tiered = [
      create(:expert_advisor, name: "Sniper Advanced Panel", tier_rank: 1),
      create(:expert_advisor, name: "Pandora Box", tier_rank: 2),
      create(:expert_advisor, name: "XAU HFT Scalper", tier_rank: 3)
    ]
    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :en)

    positions = tiered.map { |ea| response.body.index(ea.name) }
    expect(positions).to all(be_present)
    expect(positions).to eq(positions.sort)
  end

  it "filters expert advisors by status" do
    active_ea = create(:expert_advisor, name: "Active EA")
    trial_ea = create(:expert_advisor, name: "Trial EA")
    expired_ea = create(:expert_advisor, name: "Expired EA")

    create(:license, user: user, expert_advisor: active_ea, status: "active")
    create(:license, user: user, expert_advisor: trial_ea, status: "trial")
    create(:license, user: user, expert_advisor: expired_ea, status: "expired")

    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :en, status: "trial")

    expect(response).to be_successful
    expect(response.body).to include("Trial EA")
    expect(response.body).not_to include("Active EA")
    expect(response.body).not_to include("Expired EA")
  end

  it "filters expert advisors by type with localized labels" do
    indicator_ea = create(:expert_advisor, name: "Indicator EA", ea_type: :indicator)
    script_ea = create(:expert_advisor, name: "Script EA", ea_type: :script)

    sign_in user, scope: :user

    get dashboard_expert_advisors_path(locale: :es, type: "indicator")

    expect(response).to be_successful
    expect(response.body).to include("Indicator EA")
    expect(response.body).not_to include("Script EA")
    expect(response.body).to include(I18n.t("dashboard.expert_advisors.types.indicator", locale: :es))
  end
end
