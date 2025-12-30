class BackfillExpertAdvisorGuides < ActiveRecord::Migration[8.0]
  class ExpertAdvisor < ActiveRecord::Base
    self.table_name = "expert_advisors"
  end

  def up
    ExpertAdvisor.reset_column_information

    ExpertAdvisor.find_each do |advisor|
      documents = advisor.attributes["documents"]
      next if documents.blank?

      docs = documents.is_a?(Hash) ? documents.with_indifferent_access : JSON.parse(documents)

      updates = {}
      updates[:doc_guide_en] = read_doc(docs[:markdown_en] || docs[:manual_en]) if advisor.doc_guide_en.blank?
      updates[:doc_guide_es] = read_doc(docs[:markdown_es] || docs[:manual_es]) if advisor.doc_guide_es.blank?
      updates.compact!

      advisor.update_columns(updates) if updates.present?
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def read_doc(path)
    return if path.blank?

    absolute = Rails.root.join(path.delete_prefix("/"))
    return unless File.exist?(absolute)

    File.read(absolute)
  end
end
