require "rails_helper"

RSpec.describe "Product releases admin", type: :request do
  def attach_io(record, attachment_name, contents:, filename:)
    record.public_send(attachment_name).attach(
      io: StringIO.new(contents),
      filename: filename,
      content_type: "application/x-rar-compressed"
    )
  end

  it "allows admins to publish a grouped product release" do
    admin = create(:user, :admin)
    expert_advisor = create(:expert_advisor)
    addon_product = create(:marketplace_product, title_en: "Deploy Add-on")
    create(:addon, billing_plan: addon_product.billing_plan, addonable: expert_advisor)
    sign_in admin, scope: :user

    expect {
      post publish_admin_product_releases_path
    }.to change(ProductRelease, :count).by(1)

    release = ProductRelease.last
    expect(response).to redirect_to(admin_product_release_path(release))
    expect(release.product_release_items.map(&:product_kind)).to include("addon")
  end

  it "returns a no-op notice when no qualifying changes are found" do
    admin = create(:user, :admin)
    expert_advisor = create(:expert_advisor)
    attach_io(expert_advisor, :ea_files, contents: "ea-v1", filename: "ea.rar")
    sign_in admin, scope: :user

    post publish_admin_product_releases_path
    expect(ProductRelease.count).to eq(0)

    expect {
      post publish_admin_product_releases_path
    }.not_to change(ProductRelease, :count)

    expect(response).to redirect_to(admin_product_releases_path)
  end
end
