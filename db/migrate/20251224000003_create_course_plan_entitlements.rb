class CreateCoursePlanEntitlements < ActiveRecord::Migration[7.1]
  def change
    create_table :course_plan_entitlements do |t|
      t.references :course, null: false, foreign_key: true
      t.references :billing_plan, null: false, foreign_key: true

      t.timestamps
    end

    add_index :course_plan_entitlements, [:course_id, :billing_plan_id], unique: true, name: "index_course_entitlements_unique"
  end
end
