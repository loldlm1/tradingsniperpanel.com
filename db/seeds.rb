return unless defined?(ExpertAdvisor)

expert_advisors = [
  {
    name: "Sniper Advanced Panel",
    description: "Risk-first trading panel with crosshair scope, grid depth control, and hotkey-driven execution.",
    ea_type: :ea_tool,
    trial_enabled: true,
    allowed_subscription_tiers: %w[basic hft pro],
    documents: {
      markdown_en: "docs_eas/sniper_advanced_panel/Manual_EN.md",
      markdown_es: "docs_eas/sniper_advanced_panel/Manual_ES.md",
      pdf_es: "docs_eas/sniper_advanced_panel/sniper_advanced_panel_es.pdf",
      presentation_es: "docs_eas/sniper_advanced_panel/sniper_advanced_panel_presentation_es.pdf"
    }
  },
  {
    name: "XAUUSD HFT EA",
    description: "Gold-focused high-frequency robot optimized for tight spreads and fast execution.",
    ea_type: :ea_robot,
    trial_enabled: true,
    allowed_subscription_tiers: %w[hft pro],
    documents: {
      markdown_en: "docs_eas/sniper_advanced_panel/Manual_EN.md",
      markdown_es: "docs_eas/sniper_advanced_panel/Manual_ES.md",
      pdf_es: "docs_eas/sniper_advanced_panel/sniper_advanced_panel_es.pdf"
    }
  },
  {
    name: "PANDORA BOX EA",
    description: "Adaptive multi-symbol EA with protective filters and dynamic risk throttling.",
    ea_type: :ea_robot,
    trial_enabled: true,
    allowed_subscription_tiers: %w[pro],
    documents: {
      markdown_en: "docs_eas/sniper_advanced_panel/Manual_EN.md",
      markdown_es: "docs_eas/sniper_advanced_panel/Manual_ES.md",
      pdf_es: "docs_eas/sniper_advanced_panel/sniper_advanced_panel_es.pdf"
    }
  }
]

expert_advisors.each do |attrs|
  documents = attrs.delete(:documents)
  allowed_tiers = attrs.delete(:allowed_subscription_tiers)

  record = ExpertAdvisor.unscoped.find_or_initialize_by(name: attrs[:name])
  record.assign_attributes(attrs)
  record.documents = documents
  record.allowed_subscription_tiers = allowed_tiers
  record.deleted_at = nil
  record.save!
end
