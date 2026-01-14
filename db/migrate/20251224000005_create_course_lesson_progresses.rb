class CreateCourseLessonProgresses < ActiveRecord::Migration[7.1]
  def change
    create_table :course_lesson_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course_lesson, null: false, foreign_key: true
      t.string :status, null: false, default: "started"
      t.integer :progress_seconds, null: false, default: 0
      t.datetime :completed_at
      t.datetime :last_watched_at

      t.timestamps
    end

    add_index :course_lesson_progresses, [:user_id, :course_lesson_id], unique: true, name: "index_course_lesson_progress_unique"
  end
end
