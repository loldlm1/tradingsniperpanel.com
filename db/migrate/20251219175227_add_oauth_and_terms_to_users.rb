class AddOauthAndTermsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :oauth_data, :jsonb, default: {}, null: false
    add_column :users, :terms_accepted_at, :datetime
    add_column :users, :role, :integer, default: 0, null: false

    add_index :users, [:provider, :uid], unique: true
  end
end
