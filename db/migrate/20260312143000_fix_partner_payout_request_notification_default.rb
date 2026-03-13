class FixPartnerPayoutRequestNotificationDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :partner_payout_requests, :notification_status, from: 1, to: 0
  end
end
