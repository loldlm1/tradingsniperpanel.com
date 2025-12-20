class CreateBrokerAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :broker_accounts do |t|
      t.string :name
      t.string :company, null: false
      t.bigint :account_number, null: false
      t.integer :account_type, null: false, default: 0
      t.references :license, null: false, foreign_key: true

      t.timestamps
    end

    add_index :broker_accounts, [:company, :account_number, :account_type], unique: true, name: "index_broker_accounts_on_company_number_type"
  end
end
