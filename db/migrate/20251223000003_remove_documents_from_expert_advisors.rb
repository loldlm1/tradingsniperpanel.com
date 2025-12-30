class RemoveDocumentsFromExpertAdvisors < ActiveRecord::Migration[8.0]
  def change
    remove_column :expert_advisors, :documents, :jsonb
  end
end
