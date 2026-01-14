class CreateCourseModules < ActiveRecord::Migration[7.1]
  def change
    create_table :course_modules do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title_en, null: false
      t.string :title_es, null: false
      t.string :summary_en
      t.string :summary_es

      t.timestamps
    end

    add_index :course_modules, [:course_id, :position]
  end
end
