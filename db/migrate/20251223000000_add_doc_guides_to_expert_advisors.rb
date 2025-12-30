class AddDocGuidesToExpertAdvisors < ActiveRecord::Migration[8.0]
  def change
    add_column :expert_advisors, :doc_guide_en, :text
    add_column :expert_advisors, :doc_guide_es, :text
  end
end
