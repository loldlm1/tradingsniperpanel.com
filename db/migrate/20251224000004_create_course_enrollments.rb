class CreateCourseEnrollments < ActiveRecord::Migration[7.1]
  def change
    create_table :course_enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :last_lesson, foreign_key: { to_table: :course_lessons }
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :progress_percent, null: false, default: 0

      t.timestamps
    end

    add_index :course_enrollments, [:user_id, :course_id], unique: true
  end
end
