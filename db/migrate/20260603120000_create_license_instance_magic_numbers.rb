class CreateLicenseInstanceMagicNumbers < ActiveRecord::Migration[8.0]
  def change
    create_table :license_instance_magic_numbers do |t|
      t.references :license, null: false, foreign_key: true
      t.references :broker_account, null: false, foreign_key: true
      t.references :expert_advisor, null: false, foreign_key: true
      t.string :source, null: false
      t.string :email, null: false
      t.string :instance_id, null: false
      t.bigint :magic_number, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :license_instance_magic_numbers,
              [ :broker_account_id, :expert_advisor_id, :instance_id ],
              unique: true,
              name: "index_license_instance_magic_on_identity"

    add_index :license_instance_magic_numbers,
              [ :broker_account_id, :magic_number ],
              unique: true,
              name: "index_license_instance_magic_on_broker_magic"

    add_check_constraint :license_instance_magic_numbers,
                         "magic_number > 0",
                         name: "license_instance_magic_numbers_magic_positive_check"

    add_check_constraint :license_instance_magic_numbers,
                         "char_length(instance_id) <= 64 AND instance_id ~ '^[A-Za-z0-9_-]+$'",
                         name: "license_instance_magic_numbers_instance_id_format_check"
  end
end
