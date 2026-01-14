class CreateMarketplaceProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :marketplace_products do |t|
      t.string :slug, null: false
      t.string :key, null: false
      t.string :status, null: false, default: "draft"
      t.integer :sort_order, null: false, default: 0
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.text :summary_en
      t.text :summary_es
      t.text :description_en
      t.text :description_es
      t.references :billing_plan, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :marketplace_products, :slug, unique: true
    add_index :marketplace_products, :key, unique: true
    add_index :marketplace_products, :status
    add_index :marketplace_products, :billing_plan_id, unique: true
  end
end
