class CreatePromotionCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :promotion_codes do |t|
      t.string :code, null: false
      t.integer :percent_off, null: false
      t.boolean :active, null: false, default: false
      t.datetime :archived_at
      t.text :title_en, null: false
      t.text :title_es, null: false
      t.text :body_en, null: false
      t.text :body_es, null: false
      t.string :cta_label_en, null: false
      t.string :cta_label_es, null: false
      t.string :stripe_coupon_id
      t.string :stripe_promotion_code_id
      t.datetime :expires_at
      t.integer :max_redemptions
      t.timestamps
    end

    add_index :promotion_codes, :archived_at
    add_index :promotion_codes, :stripe_coupon_id
    add_index :promotion_codes, :stripe_promotion_code_id
    add_index :promotion_codes,
              "lower(code)",
              unique: true,
              where: "archived_at IS NULL",
              name: "index_promotion_codes_on_lower_code_kept"
    add_index :promotion_codes,
              :active,
              unique: true,
              where: "active = true AND archived_at IS NULL",
              name: "index_promotion_codes_on_single_active"
  end
end
