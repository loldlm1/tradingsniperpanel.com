class UpdateAddonsAddonableTypeCheck < ActiveRecord::Migration[7.1]
  def change
    remove_check_constraint :addons, name: "addons_addonable_type_check"
    add_check_constraint :addons, "addonable_type IN ('ExpertAdvisor', 'Course', 'MarketplaceAsset')",
                         name: "addons_addonable_type_check"
  end
end
