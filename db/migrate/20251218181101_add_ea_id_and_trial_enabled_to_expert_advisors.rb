require "securerandom"

class AddEaIdAndTrialEnabledToExpertAdvisors < ActiveRecord::Migration[8.0]
  class ExpertAdvisor < ApplicationRecord
    self.table_name = "expert_advisors"
  end

  def up
    add_column :expert_advisors, :ea_id, :string
    add_column :expert_advisors, :trial_enabled, :boolean, default: true, null: false

    ExpertAdvisor.reset_column_information

    say_with_time "Backfilling expert advisor EA IDs" do
      ExpertAdvisor.unscoped.find_each do |ea|
        ea_id = generate_ea_id(ea)
        ea.update_columns(ea_id:)
      end
    end

    change_column_null :expert_advisors, :ea_id, false
    add_index :expert_advisors, :ea_id, unique: true
  end

  def down
    remove_index :expert_advisors, :ea_id
    remove_column :expert_advisors, :ea_id
    remove_column :expert_advisors, :trial_enabled
  end

  private

  def generate_ea_id(ea)
    base = ea.name.to_s.parameterize.presence || "expert-advisor"
    candidate = "#{base}-#{SecureRandom.hex(4)}"

    while ExpertAdvisor.unscoped.where(ea_id: candidate).exists?
      candidate = "#{base}-#{SecureRandom.hex(4)}"
    end

    candidate
  end
end
