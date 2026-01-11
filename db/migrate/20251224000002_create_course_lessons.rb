class CreateCourseLessons < ActiveRecord::Migration[7.1]
  def change
    create_table :course_lessons do |t|
      t.references :course_module, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.string :summary_en
      t.string :summary_es
      t.text :body_markdown_en
      t.text :body_markdown_es
      t.string :stream_uid
      t.integer :duration_seconds, null: false, default: 0

      t.timestamps
    end

    add_index :course_lessons, [:course_module_id, :position]
    add_index :course_lessons, :stream_uid
  end
end
