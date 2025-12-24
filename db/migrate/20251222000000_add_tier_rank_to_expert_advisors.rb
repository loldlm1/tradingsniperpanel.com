class AddTierRankToExpertAdvisors < ActiveRecord::Migration[8.0]
  def change
    add_column :expert_advisors, :tier_rank, :integer, null: false, default: 0
    add_index :expert_advisors, :tier_rank
  end
end
