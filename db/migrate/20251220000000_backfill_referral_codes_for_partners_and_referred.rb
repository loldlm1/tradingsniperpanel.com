class BackfillReferralCodesForPartnersAndReferred < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    say_with_time "Ensuring referral codes for partners and referred traders" do
      User.where(role: User.roles[:partner]).find_each do |user|
        user.referral_codes.first_or_create
      end

      User.joins(:referral).find_each do |user|
        user.referral_codes.first_or_create
      end
    end
  end

  def down
    # no-op
  end
end
