class AddTokenVersionToLicenses < ActiveRecord::Migration[8.0]
  def change
    add_column :licenses, :token_version, :integer, default: 1, null: false
    add_column :licenses, :token_rotated_at, :datetime

    add_check_constraint :licenses,
                         "token_version > 0",
                         name: "licenses_token_version_positive_check"
  end
end
