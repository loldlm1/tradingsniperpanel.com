class CreateProductReleases < ActiveRecord::Migration[8.0]
  def change
    create_table :product_releases do |t|
      t.references :published_by, foreign_key: { to_table: :users }
      t.datetime :published_at, null: false

      t.timestamps
    end

    create_table :product_release_items do |t|
      t.references :product_release, null: false, foreign_key: true
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :product_kind, null: false
      t.string :action_type, null: false
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :product_release_items, [:subject_type, :subject_id]
    add_index :product_release_items, :product_kind
    add_index :product_release_items, :action_type

    create_table :product_release_snapshots do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :product_kind, null: false
      t.string :signature, null: false
      t.datetime :tracked_at, null: false

      t.timestamps
    end

    add_index :product_release_snapshots,
              [:subject_type, :subject_id, :product_kind],
              unique: true,
              name: "index_product_release_snapshots_on_subject_and_kind"

    create_table :product_release_dismissals do |t|
      t.references :product_release, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :dismissed_at, null: false

      t.timestamps
    end

    add_index :product_release_dismissals,
              [:product_release_id, :user_id],
              unique: true,
              name: "index_product_release_dismissals_on_release_and_user"
  end
end
