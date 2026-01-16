# frozen_string_literal: true

class CreateRevenueSplitRules < ActiveRecord::Migration[8.0]
  def change
    create_table :revenue_split_rules do |t|
      t.datetime :effective_at, null: false
      t.integer :us_percent, null: false
      t.integer :client_percent, null: false
      t.text :note

      t.timestamps
    end

    add_index :revenue_split_rules, :effective_at
  end
end
