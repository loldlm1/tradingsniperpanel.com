return unless defined?(ExpertAdvisor)

manual_en_path = Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_EN.md")
manual_es_path = Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_ES.md")
manual_en = manual_en_path.exist? ? File.read(manual_en_path) : ""
manual_es = manual_es_path.exist? ? File.read(manual_es_path) : ""

bundle_path = Rails.root.join("db", "seeds", "fixtures", "ea_bundle.rar")

attach_bundle = lambda do |record|
  return unless bundle_path.exist?
  return if record.ea_files.attached?

  File.open(bundle_path) do |file|
    record.ea_files.attach(
      io: file,
      filename: "ea_bundle.rar",
      content_type: "application/x-rar-compressed"
    )
  end
end

expert_advisors = [
  {
    name: "Sniper Advanced Panel",
    tier_rank: 1,
    ea_id: "sniper_advanced_panel",
    description: "Risk-first trading panel with crosshair scope, grid depth control, and hotkey-driven execution.",
    ea_type: :ea_tool,
    trial_enabled: true,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: manual_en,
    doc_guide_es: manual_es
  },
  {
    name: "PANDORA BOX EA",
    tier_rank: 2,
    ea_id: "pandora_box",
    description: "Adaptive multi-symbol EA with protective filters and dynamic risk throttling.",
    ea_type: :ea_robot,
    trial_enabled: true,
    allowed_subscription_tiers: %w[hft pro],
    doc_guide_en: manual_en,
    doc_guide_es: manual_es
  },
	{
    name: "XAUUSD HFT EA",
    ea_id: "xau_hft_scalper",
    tier_rank: 3,
    description: "Gold-focused high-frequency robot optimized for tight spreads and fast execution.",
    ea_type: :ea_robot,
    trial_enabled: true,
    allowed_subscription_tiers: %w[pro],
    doc_guide_en: manual_en,
    doc_guide_es: manual_es
  }
]

expert_advisors.each do |attrs|
  allowed_tiers = attrs.delete(:allowed_subscription_tiers)

  record = ExpertAdvisor.unscoped.find_or_initialize_by(name: attrs[:name])
  record.assign_attributes(attrs)
  record.allowed_subscription_tiers = allowed_tiers
  record.deleted_at = nil
  record.save!

  attach_bundle.call(record)
end
