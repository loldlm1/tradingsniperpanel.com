return unless defined?(ExpertAdvisor)

sniper_bundle_path = Rails.root.join("docs_eas", "sniper_advanced_panel", "SniperAdvancedPanel.rar")
pandora_bundle_path = Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.rar")

bundle_paths = {
  "sniper_advanced_panel" => sniper_bundle_path,
  "pandora_box" => pandora_bundle_path
}

Seeds::ExpertAdvisors.core_definitions.each do |attrs|
  bundle_path = bundle_paths[attrs[:ea_id]]
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: bundle_path)
end
