class AddAccessSourceToLicenses < ActiveRecord::Migration[7.1]
  def change
    add_column :licenses, :access_source, :string
    add_index :licenses, :access_source
  end
end
