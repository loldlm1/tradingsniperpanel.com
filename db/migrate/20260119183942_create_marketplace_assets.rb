class CreateMarketplaceAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :marketplace_assets do |t|
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.integer :sort_order, null: false, default: 0
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.text :summary_en
      t.text :summary_es
      t.text :description_markdown_en
      t.text :description_markdown_es

      t.timestamps
    end

    add_index :marketplace_assets, :slug, unique: true
    add_index :marketplace_assets, :status
  end
end
