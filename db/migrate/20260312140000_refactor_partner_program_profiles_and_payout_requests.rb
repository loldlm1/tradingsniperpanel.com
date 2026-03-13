require "securerandom"

class RefactorPartnerProgramProfilesAndPayoutRequests < ActiveRecord::Migration[8.0]
  class MigrationPartnerProfile < ApplicationRecord
    self.table_name = "partner_profiles"
  end

  class MigrationPartnerPayoutRequest < ApplicationRecord
    self.table_name = "partner_payout_requests"
  end

  class MigrationReferralCode < ApplicationRecord
    self.table_name = "refer_referral_codes"
  end

  def up
    add_column :partner_profiles, :referral_code, :string
    add_column :partner_profiles, :commission_percent, :integer

    add_column :partner_payout_requests, :notification_status, :integer, default: 1, null: false
    add_column :partner_payout_requests, :notification_sent_at, :datetime
    add_column :partner_payout_requests, :notification_failed_at, :datetime
    add_column :partner_payout_requests, :notification_failure_message, :text

    backfill_partner_profiles!
    backfill_payout_notifications!

    change_column_null :partner_profiles, :referral_code, false
    change_column_null :partner_profiles, :commission_percent, false

    add_index :partner_profiles, :referral_code, unique: true
    add_index :partner_payout_requests, :notification_status
    add_index :partner_payout_requests,
              :partner_profile_id,
              unique: true,
              where: "status = 0",
              name: "index_partner_payout_requests_on_profile_pending"
  end

  def down
    remove_index :partner_payout_requests, name: "index_partner_payout_requests_on_profile_pending"
    remove_index :partner_payout_requests, :notification_status
    remove_index :partner_profiles, :referral_code

    remove_column :partner_payout_requests, :notification_failure_message
    remove_column :partner_payout_requests, :notification_failed_at
    remove_column :partner_payout_requests, :notification_sent_at
    remove_column :partner_payout_requests, :notification_status

    remove_column :partner_profiles, :commission_percent
    remove_column :partner_profiles, :referral_code
  end

  private

  def backfill_partner_profiles!
    say_with_time "Backfilling partner profile referral codes and commission percent" do
      MigrationPartnerProfile.reset_column_information
      MigrationReferralCode.reset_column_information

      MigrationPartnerProfile.find_each do |profile|
        next if profile.user_id.blank?

        referral_code = normalized_referral_code(existing_referral_code_for(profile.user_id)) || generate_unique_code
        commission_percent = profile.discount_percent.to_i
        commission_percent = 0 if commission_percent.negative?

        profile.update_columns(
          referral_code: referral_code,
          commission_percent: commission_percent,
          updated_at: Time.current
        )

        sync_referral_code!(user_id: profile.user_id, code: referral_code)
      end
    end
  end

  def backfill_payout_notifications!
    say_with_time "Marking existing partner payout notifications as sent" do
      MigrationPartnerPayoutRequest.reset_column_information

      MigrationPartnerPayoutRequest.find_each do |request|
        request.update_columns(
          notification_status: 1,
          notification_sent_at: request.requested_at || request.created_at,
          updated_at: Time.current
        )
      end
    end
  end

  def existing_referral_code_for(user_id)
    MigrationReferralCode.where(referrer_type: "User", referrer_id: user_id).order(:created_at, :id).pick(:code)
  end

  def sync_referral_code!(user_id:, code:)
    primary = MigrationReferralCode.where(referrer_type: "User", referrer_id: user_id).order(:created_at, :id).first

    if primary
      primary.update_columns(code: code, updated_at: Time.current)
      retire_duplicate_codes!(user_id:, keep_id: primary.id)
      return
    end

    MigrationReferralCode.create!(
      referrer_type: "User",
      referrer_id: user_id,
      code: code
    )
  end

  def retire_duplicate_codes!(user_id:, keep_id:)
    duplicates = MigrationReferralCode.where(referrer_type: "User", referrer_id: user_id).where.not(id: keep_id)

    duplicates.find_each.with_index(1) do |referral_code, index|
      referral_code.update_columns(
        code: retired_duplicate_code(index),
        updated_at: Time.current
      )
    end
  end

  def retired_duplicate_code(index)
    loop do
      candidate = "OLD#{index}#{SecureRandom.alphanumeric(10).upcase}"
      return candidate unless MigrationReferralCode.exists?(code: candidate)
    end
  end

  def generate_unique_code
    loop do
      candidate = "PART#{SecureRandom.alphanumeric(8).upcase}"
      return candidate unless MigrationPartnerProfile.exists?(referral_code: candidate) || MigrationReferralCode.exists?(code: candidate)
    end
  end

  def normalized_referral_code(value)
    value.to_s.strip.upcase.presence
  end
end
