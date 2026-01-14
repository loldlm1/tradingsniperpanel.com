class CreateCourses < ActiveRecord::Migration[7.1]
  def change
    create_table :courses do |t|
      t.string :slug, null: false
      t.string :status, null: false, default: "draft"
      t.string :category, null: false
      t.integer :position, null: false, default: 0
      t.datetime :published_at
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.string :summary_en
      t.string :summary_es
      t.text :description_en
      t.text :description_es

      t.timestamps
    end

    add_index :courses, :slug, unique: true
    add_index :courses, :status
    add_index :courses, :category
  end
end
