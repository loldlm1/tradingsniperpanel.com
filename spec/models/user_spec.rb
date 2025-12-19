require 'rails_helper'

RSpec.describe User, type: :model do
  describe "#preferred_locale_code" do
    it "returns preferred locale when present" do
      user = build(:user, preferred_locale: "es")

      expect(user.preferred_locale_code).to eq("es")
    end

    it "falls back to default locale when blank" do
      user = build(:user, preferred_locale: nil)

      expect(user.preferred_locale_code).to eq(I18n.default_locale)
    end
  end

  describe "#stripe_customer_attributes" do
    it "includes metadata about the user" do
      user = create(:user, preferred_locale: "es")
      metadata = user.stripe_customer_attributes[:metadata]

      expect(metadata[:user_id]).to eq(user.id)
      expect(metadata[:referral_code]).to eq(user.referral_codes.first.code)
      expect(metadata[:preferred_locale]).to eq("es")
    end
  end

  describe "#pay_customer_name" do
    it "uses name when present" do
      user = build(:user, name: "Jane Doe")

      expect(user.pay_customer_name).to eq("Jane Doe")
    end

    it "falls back to email when name is blank" do
      user = build(:user, name: nil, email: "test@example.com")

      expect(user.pay_customer_name).to eq("test@example.com")
    end
  end

  describe "#ensure_referral_code" do
    it "creates a referral code after creation" do
      user = create(:user)

      expect(user.referral_codes.count).to eq(1)
      expect(user.referral_codes.first.code).to be_present
    end
  end

  describe "roles" do
    it "defaults to trader" do
      user = create(:user)

      expect(user.role).to eq("trader")
      expect(user).to be_trader
    end
  end

  describe "terms acceptance" do
    it "sets terms_accepted_at when checkbox is checked" do
      user = build(:user, terms_of_service: "1", terms_accepted_at: nil)

      expect(user).to be_valid
      expect(user.terms_accepted_at).to be_present
    end

    it "is invalid without accepting terms on create" do
      user = build(:user, terms_of_service: "0", terms_accepted_at: nil)

      expect(user).not_to be_valid
      expect(user.errors[:terms_of_service]).to be_present
    end
  end
end
