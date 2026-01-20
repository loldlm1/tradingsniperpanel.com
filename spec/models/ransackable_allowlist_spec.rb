require "rails_helper"

RSpec.describe "Ransack allowlists" do
  shared_examples "ransackable model" do |model_class, attributes:, associations:|
    it "defines ransackable associations" do
      expect(model_class).to respond_to(:ransackable_associations)
      current = model_class.ransackable_associations
      if associations.empty?
        expect(current).to be_empty
      else
        expect(current).to include(*associations)
      end
    end

    it "defines ransackable attributes" do
      expect(model_class).to respond_to(:ransackable_attributes)
      expect(model_class.ransackable_attributes).to include(*attributes)
    end
  end

  include_examples "ransackable model",
                   ExpertAdvisor,
                   attributes: %w[ea_id ea_type name trial_enabled],
                   associations: %w[tags]

  include_examples "ransackable model",
                   Course,
                   attributes: %w[category slug status title_en title_es],
                   associations: %w[tags]

  include_examples "ransackable model",
                   MarketplaceAsset,
                   attributes: %w[slug status title_en title_es],
                   associations: %w[tags]

  include_examples "ransackable model",
                   MarketplaceProduct,
                   attributes: %w[slug status title_en title_es],
                   associations: []
end

RSpec.describe ActsAsTaggableOn::Tag, type: :model do
  it "allows tag name searches" do
    expect(described_class.ransackable_attributes).to include("name")
  end
end
