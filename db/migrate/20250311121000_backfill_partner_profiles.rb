class BackfillPartnerProfiles < ActiveRecord::Migration[8.0]
  def up
    default_percent = ENV.fetch("REFER_DEFAULT_DISCOUNT_PERCENT", "0").to_i

    say_with_time "Backfilling partner profiles" do
      User.where(role: User.roles[:partner]).find_each do |user|
        profile = PartnerProfile.find_or_initialize_by(user_id: user.id)
        profile.discount_percent ||= default_percent
        profile.payout_mode ||= PartnerProfile.payout_modes[:once_paid]
        profile.started_at ||= user.created_at
        profile.active = true if profile.active.nil?
        profile.save!(validate: false)
      end
    end
  end

  def down
    # no-op
  end
end
