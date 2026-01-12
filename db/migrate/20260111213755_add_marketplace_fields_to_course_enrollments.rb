class AddMarketplaceFieldsToCourseEnrollments < ActiveRecord::Migration[7.1]
  def change
    add_column :course_enrollments, :access_source, :string
    add_column :course_enrollments, :purchased_at, :datetime
    add_reference :course_enrollments, :pay_charge, foreign_key: { to_table: :pay_charges }

    add_index :course_enrollments, :access_source
  end
end
