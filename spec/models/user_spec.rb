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
      user = create(:user, :partner, preferred_locale: "es")
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
    it "creates a referral code after creation for partners" do
      user = create(:user, :partner)

      expect(user.referral_codes.count).to eq(1)
      expect(user.referral_codes.first.code).to be_present
    end

    it "does not create a referral code for traders without referrers" do
      user = create(:user)

      expect(user.referral_codes.count).to eq(0)
    end

    it "creates a referral code for referred traders" do
      referrer = create(:user, :partner)
      user = create(:user)

      Referrals::AttachReferrer.new(user:, code: referrer.referral_codes.first.code).call

      expect(user.referral_codes.count).to eq(1)
      expect(user.referral_codes.first.code).to be_present
    end
  end

  describe "#send_devise_notification" do
    it "delivers Devise notifications asynchronously" do
      user = create(:user)
      mailer = class_double("Devise::Mailer")
      mail_delivery = instance_double(ActionMailer::MessageDelivery)

      allow(user).to receive(:devise_mailer).and_return(mailer)
      allow(mailer).to receive(:send).with(:reset_password_instructions, user, "token-123").and_return(mail_delivery)

      expect(mail_delivery).to receive(:deliver_later)
      expect(mail_delivery).not_to receive(:deliver_now)

      user.send_devise_notification(:reset_password_instructions, "token-123")
    end
  end

  describe "roles" do
    it "defaults to trader" do
      user = create(:user)

      expect(user.role).to eq("trader")
      expect(user).to be_trader
    end

    it "supports full_trader as a role" do
      user = create(:user, :full_trader)

      expect(user).to be_full_trader
    end

    it "flags privileged full-access roles" do
      expect(create(:user, :admin).privileged_full_access?).to be(true)
      expect(create(:user, :master_admin).privileged_full_access?).to be(true)
      expect(create(:user, :full_trader).privileged_full_access?).to be(true)
      expect(create(:user).privileged_full_access?).to be(false)
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

  describe "ransack allowlists" do
    it "limits ransackable attributes and associations" do
      expect(described_class.ransackable_associations).to eq([])
      expect(described_class.ransackable_attributes).to match_array(
        %w[created_at email id name preferred_locale role]
      )
    end
  end
end
