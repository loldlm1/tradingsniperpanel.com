require "rails_helper"

RSpec.describe ProductReleases::Publish do
  def attach_io(record, attachment_name, contents:, filename:)
    record.public_send(attachment_name).attach(
      io: StringIO.new(contents),
      filename: filename,
      content_type: "application/x-rar-compressed"
    )
  end

  it "creates added release items for newly available add-ons and published courses" do
    expert_advisor = create(:expert_advisor, name: "Signal EA")
    attach_io(expert_advisor, :ea_files, contents: "ea-v1", filename: "signal.rar")

    addon_product = create(:marketplace_product, title_en: "Session Filter", title_es: "Filtro de Sesion")
    create(:addon, billing_plan: addon_product.billing_plan, addonable: expert_advisor)

    course = create(:course, title_en: "Advanced Risk", title_es: "Riesgo Avanzado")

    result = described_class.new.call

    expect(result).to be_published
    expect(result.item_count).to eq(2)
    expect(result.changed_items.map { |item| [item[:product_kind], item[:action_type]] }).to match_array([
      ["addon", "added"],
      ["course", "added"]
    ])
    expect(ProductReleaseSnapshot.where(product_kind: "expert_advisor", subject_id: expert_advisor.id)).to exist
    expect(ProductReleaseSnapshot.where(product_kind: "addon", subject_id: addon_product.id)).to exist
    expect(ProductReleaseSnapshot.where(product_kind: "course", subject_id: course.id)).to exist
  end

  it "creates an updated release item when an expert advisor file changes after the initial snapshot" do
    expert_advisor = create(:expert_advisor, name: "Fibonacci Sniper")
    attach_io(expert_advisor, :ea_files, contents: "ea-v1", filename: "fibonacci.rar")

    first_result = described_class.new.call
    expect(first_result).not_to be_published

    expert_advisor.ea_files.purge
    attach_io(expert_advisor, :ea_files, contents: "ea-v2", filename: "fibonacci.rar")

    second_result = described_class.new.call

    expect(second_result).to be_published
    expect(second_result.item_count).to eq(1)
    expect(second_result.release.product_release_items.first).to have_attributes(
      product_kind: "expert_advisor",
      action_type: "updated",
      title_en: "Fibonacci Sniper"
    )
  end

  it "creates an updated release item when an active expert advisor bundle changes" do
    expert_advisor = create(:expert_advisor, name: "Atlas Bundle EA")
    bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base")
    attach_io(bundle, :bundle_file, contents: "bundle-v1", filename: "atlas_base.rar")

    described_class.new.call

    bundle.bundle_file.purge
    attach_io(bundle, :bundle_file, contents: "bundle-v2", filename: "atlas_base.rar")

    result = described_class.new.call

    expect(result).to be_published
    expect(result.release.product_release_items.first).to have_attributes(
      product_kind: "expert_advisor",
      action_type: "updated",
      title_en: "Atlas Bundle EA"
    )
  end

  it "returns a no-op result when re-published without qualifying changes" do
    course = create(:course, title_en: "Launch Course")

    first_result = described_class.new.call
    expect(first_result).to be_published
    expect(ProductRelease.count).to eq(1)

    second_result = described_class.new.call

    expect(second_result).not_to be_published
    expect(second_result.item_count).to eq(0)
    expect(ProductRelease.count).to eq(1)
    expect(ProductReleaseSnapshot.where(product_kind: "course", subject_id: course.id)).to exist
  end
end
