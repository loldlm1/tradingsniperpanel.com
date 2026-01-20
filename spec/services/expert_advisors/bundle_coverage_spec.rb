require "rails_helper"

RSpec.describe ExpertAdvisors::BundleCoverage do
  it "returns empty coverage when no add-ons exist" do
    expert_advisor = create(:expert_advisor)

    result = described_class.new(expert_advisor: expert_advisor).call

    expect(result.required_keys).to eq([])
    expect(result.missing_keys).to eq([])
  end

  it "reports missing bundle keys for add-on combinations" do
    expert_advisor = create(:expert_advisor)
    create(:addon, addonable: expert_advisor, key: "addon_alpha")
    create(:addon, addonable: expert_advisor, key: "addon_beta")

    base_bundle = create(:expert_advisor_bundle, expert_advisor: expert_advisor, bundle_key: "base", required_addon_keys: "")
    alpha_bundle = create(
      :expert_advisor_bundle,
      expert_advisor: expert_advisor,
      bundle_key: "addon_alpha",
      required_addon_keys: "addon_alpha"
    )

    file_path = Rails.root.join("spec", "fixtures", "files", "ea_bundle.rar")
    File.open(file_path) do |file|
      base_bundle.bundle_file.attach(
        io: file,
        filename: "ea_bundle.rar",
        content_type: "application/x-rar-compressed"
      )
    end
    File.open(file_path) do |file|
      alpha_bundle.bundle_file.attach(
        io: file,
        filename: "ea_bundle.rar",
        content_type: "application/x-rar-compressed"
      )
    end

    result = described_class.new(expert_advisor: expert_advisor).call

    expect(result.required_keys).to match_array(%w[base addon_alpha addon_beta addon_alpha__addon_beta])
    expect(result.missing_keys).to match_array(%w[addon_beta addon_alpha__addon_beta])
  end

  it "includes additional add-on keys in coverage" do
    expert_advisor = create(:expert_advisor)

    result = described_class.new(
      expert_advisor: expert_advisor,
      additional_addon_keys: ["addon_extra"]
    ).call

    expect(result.required_keys).to match_array(%w[base addon_extra])
    expect(result.missing_keys).to match_array(%w[base addon_extra])
  end
end
