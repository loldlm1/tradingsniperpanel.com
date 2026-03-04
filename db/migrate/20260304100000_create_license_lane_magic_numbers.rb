class CreateLicenseLaneMagicNumbers < ActiveRecord::Migration[8.0]
  def change
    create_table :license_lane_magic_numbers do |t|
      t.references :license, null: false, foreign_key: true
      t.string :source, null: false
      t.string :email, null: false
      t.string :company, null: false
      t.bigint :account_number, null: false
      t.string :account_type, null: false
      t.bigint :magic_number, null: false

      t.timestamps
    end

    add_index :license_lane_magic_numbers,
              [:license_id, :source, :email, :company, :account_number, :account_type],
              unique: true,
              name: "index_license_lane_magic_numbers_on_lane"

    add_index :license_lane_magic_numbers,
              :magic_number,
              unique: true,
              name: "index_license_lane_magic_numbers_on_magic_number"

    add_check_constraint :license_lane_magic_numbers,
                         "account_type IN ('real', 'demo')",
                         name: "license_lane_magic_numbers_account_type_check"

    add_check_constraint :license_lane_magic_numbers,
                         "magic_number > 0",
                         name: "license_lane_magic_numbers_magic_positive_check"
  end
end
