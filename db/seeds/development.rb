return unless defined?(ExpertAdvisor)
return unless defined?(User)

sniper_bundle_path = Rails.root.join("docs_eas", "sniper_advanced_panel", "SniperAdvancedPanel.rar")
pandora_bundle_path = Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.rar")
qa_bundle_path = Rails.root.join("db", "seeds", "fixtures", "ea_bundle.rar")

bundle_paths = {
  "sniper_advanced_panel" => sniper_bundle_path,
  "pandora_box" => pandora_bundle_path
}

Seeds::BillingPlans.seed_plans!

core_records = Seeds::ExpertAdvisors.core_definitions.map do |attrs|
  bundle_path = bundle_paths[attrs[:ea_id]]
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: bundle_path)
end

qa_definitions = [
  {
    name: "QA Trial EA",
    ea_id: "qa_trial_ea",
    tier_rank: 10,
    description: "QA-only EA for trial status checks.",
    ea_type: :ea_robot,
    trial_enabled: false,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: Seeds::ExpertAdvisors.manual_en,
    doc_guide_es: Seeds::ExpertAdvisors.manual_es
  },
  {
    name: "QA Active EA",
    ea_id: "qa_active_ea",
    tier_rank: 11,
    description: "QA-only EA for active status checks.",
    ea_type: :ea_robot,
    trial_enabled: false,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: Seeds::ExpertAdvisors.manual_en,
    doc_guide_es: Seeds::ExpertAdvisors.manual_es
  },
  {
    name: "QA Expired EA",
    ea_id: "qa_expired_ea",
    tier_rank: 12,
    description: "QA-only EA for expired status checks.",
    ea_type: :ea_robot,
    trial_enabled: false,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: Seeds::ExpertAdvisors.manual_en,
    doc_guide_es: Seeds::ExpertAdvisors.manual_es
  },
  {
    name: "QA Revoked EA",
    ea_id: "qa_revoked_ea",
    tier_rank: 13,
    description: "QA-only EA for revoked status checks.",
    ea_type: :ea_robot,
    trial_enabled: false,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: Seeds::ExpertAdvisors.manual_en,
    doc_guide_es: Seeds::ExpertAdvisors.manual_es
  },
  {
    name: "QA Locked EA",
    ea_id: "qa_locked_ea",
    tier_rank: 14,
    description: "QA-only EA for locked status checks.",
    ea_type: :ea_robot,
    trial_enabled: false,
    allowed_subscription_tiers: %w[basic hft pro],
    doc_guide_en: Seeds::ExpertAdvisors.manual_en,
    doc_guide_es: Seeds::ExpertAdvisors.manual_es
  }
]

qa_records = qa_definitions.map do |attrs|
  Seeds::ExpertAdvisors.upsert_expert_advisor(attrs.dup, bundle_path: qa_bundle_path)
end

Seeds::BillingPlans.seed_entitlements!

qa_user = User.find_or_initialize_by(email: "qa@example.com")
qa_user.name ||= "QA User"
qa_user.role ||= :trader
qa_user.terms_accepted_at ||= Time.current
if qa_user.new_record?
  qa_user.password = "Password123!"
  qa_user.password_confirmation = "Password123!"
end
qa_user.save!

encoder = Licenses::LicenseKeyEncoder.new
unless encoder.configured?
  Rails.logger.warn("Skipping QA license seeding because EA license keys are not configured.")
  return
end

def upsert_license(user:, expert_advisor:, status:, encoder:, expires_at: nil, trial_ends_at: nil, plan_interval: nil)
  license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
  license.status = status
  license.plan_interval = plan_interval
  license.expires_at = expires_at
  license.trial_ends_at = trial_ends_at
  license.source = "seed"
  license.last_synced_at = Time.current
  effective_expires_at = license.effective_expires_at
  license.encrypted_key = encoder.generate(
    email: user.email,
    ea_id: expert_advisor.ea_id,
    expires_at: effective_expires_at
  )
  license.save!
end

now = Time.current

core_records.each do |record|
  upsert_license(
    user: qa_user,
    expert_advisor: record,
    status: "active",
    plan_interval: "monthly",
    expires_at: now + 30.days,
    encoder: encoder
  )
end

qa_map = qa_records.index_by(&:ea_id)

upsert_license(
  user: qa_user,
  expert_advisor: qa_map.fetch("qa_trial_ea"),
  status: "trial",
  trial_ends_at: now + 3.days,
  encoder: encoder
)

upsert_license(
  user: qa_user,
  expert_advisor: qa_map.fetch("qa_active_ea"),
  status: "active",
  plan_interval: "monthly",
  expires_at: now + 30.days,
  encoder: encoder
)

upsert_license(
  user: qa_user,
  expert_advisor: qa_map.fetch("qa_expired_ea"),
  status: "expired",
  plan_interval: "monthly",
  expires_at: now - 2.days,
  encoder: encoder
)

upsert_license(
  user: qa_user,
  expert_advisor: qa_map.fetch("qa_revoked_ea"),
  status: "revoked",
  plan_interval: "monthly",
  expires_at: now - 1.day,
  encoder: encoder
)

return unless defined?(BrokerAccountDailyResult)

qa_brokers = ["Apex FX", "Fusion Markets", "Demo Lab", "BlueRock Markets", "Quantum Trades"]
qa_account_types = %i[real demo real]
qa_days = 60

def daily_result_exists?(broker_account, date)
  BrokerAccountDailyResult
    .where(broker_account_id: broker_account.id)
    .where("((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date) = ?", date)
    .exists?
end

def seed_daily_results(broker_account, days:, seed:)
  rng = Random.new(seed)
  end_date = Time.current.utc.to_date
  start_date = end_date - (days - 1)

  (0...days).each do |offset|
    date = start_date + offset
    next if ((broker_account.account_number + offset) % 13).zero?
    next if daily_result_exists?(broker_account, date)

    timestamp = Time.utc(date.year, date.month, date.day, 12, 0, 0).to_i
    volatility = broker_account.account_type == "real" ? 40.0 : 25.0
    trend = (offset - (days / 2.0)) * (broker_account.account_type == "real" ? 0.4 : 0.2)
    value = (rng.rand(-volatility..volatility) + trend).round(2)

    BrokerAccountDailyResult.create!(
      broker_account: broker_account,
      result_timestamp: timestamp,
      result_value: value
    )
  end
end

License.includes(:expert_advisor).where(user: qa_user).order(:id).each_with_index do |license, license_idx|
  3.times do |account_idx|
    broker_name = qa_brokers[(license_idx + account_idx) % qa_brokers.size]
    account_type = qa_account_types[account_idx % qa_account_types.size]
    account_number = 70_000 + (license_idx * 10) + account_idx

    broker_account = BrokerAccount.find_or_create_by!(
      company: broker_name,
      account_number: account_number,
      account_type: account_type
    ) do |account|
      account.name = "QA #{license.expert_advisor.name} #{account_idx + 1}"
      account.license = license
    end

    broker_account.update!(license: license) if broker_account.license_id != license.id
    seed_daily_results(broker_account, days: qa_days, seed: broker_account.account_number)
  end
end
