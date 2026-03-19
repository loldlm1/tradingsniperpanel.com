class CreateSupportRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :support_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.text :message, null: false
      t.string :locale, null: false, default: "en"

      t.timestamps
    end

    add_index :support_requests, :created_at
    add_check_constraint :support_requests, "char_length(message) > 0", name: "support_requests_message_not_blank"
  end
end
