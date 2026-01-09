return unless defined?(ExpertAdvisor)

module Seeds
  module ExpertAdvisors
    module_function

    INTRO_VIDEO_TOKEN = "[[video:docs/videos/video.mp4]]"
    OUTRO_YOUTUBE_TOKEN = "[[youtube:https://www.youtube.com/watch?v=dQw4w9WgXcQ]]"

    def manual_en
      @manual_en ||= manual_for(locale: :en)
    end

    def manual_es
      @manual_es ||= manual_for(locale: :es)
    end

    def core_definitions
      [
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
        }
      ]
    end

    def upsert_expert_advisor(attrs, bundle_path: nil)
      allowed_tiers = attrs.delete(:allowed_subscription_tiers)

      record = ExpertAdvisor.unscoped.find_or_initialize_by(name: attrs[:name])
      record.assign_attributes(attrs)
      record.allowed_subscription_tiers = allowed_tiers
      record.deleted_at = nil
      record.save!

      attach_bundle(record, bundle_path) if bundle_path
      record
    end

    def attach_bundle(record, bundle_path)
      return unless bundle_path&.exist?
      if record.ea_files.attached?
        record.ensure_bundle_filename!
        return
      end

      extension = File.extname(bundle_path.to_s)
      filename = "#{record.ea_id}#{extension.presence || ".rar"}"

      File.open(bundle_path) do |file|
        record.ea_files.attach(
          io: file,
          filename: filename,
          content_type: "application/x-rar-compressed"
        )
      end

      record.ensure_bundle_filename!
    end

    def manual_for(locale:)
      path = manual_path(locale)
      content = path.exist? ? File.read(path) : ""
      inject_media_tokens(content)
    end

    def manual_path(locale)
      locale.to_s == "es" ? manual_es_path : manual_en_path
    end

    def manual_en_path
      Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_EN.md")
    end

    def manual_es_path
      Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_ES.md")
    end

    def inject_media_tokens(markdown)
      content = markdown.to_s.dup
      content = "#{INTRO_VIDEO_TOKEN}\n\n#{content}".strip unless content.include?(INTRO_VIDEO_TOKEN)
      content = "#{content}\n\n#{OUTRO_YOUTUBE_TOKEN}\n" unless content.include?(OUTRO_YOUTUBE_TOKEN)
      content
    end
  end

  module BillingPlans
    module_function

    DEFAULT_CURRENCY = "usd"

    def definitions
      [
        plan_definition(tier: "basic", interval: "month", interval_count: 1, amount_cents: 2000, sort_order: 1),
        plan_definition(tier: "basic", interval: "year", interval_count: 1, amount_cents: 18_000, sort_order: 1),
        plan_definition(tier: "hft", interval: "month", interval_count: 1, amount_cents: 4000, sort_order: 2),
        plan_definition(tier: "hft", interval: "year", interval_count: 1, amount_cents: 36_000, sort_order: 2),
        plan_definition(tier: "pro", interval: "month", interval_count: 1, amount_cents: 6000, sort_order: 3),
        plan_definition(tier: "pro", interval: "year", interval_count: 1, amount_cents: 54_000, sort_order: 3)
      ]
    end

    def seed_plans!
      return unless stripe_configured?
      return unless defined?(Billing::PlanCreator)

      definitions.each do |attrs|
        Billing::PlanCreator.new(attrs).call
      end
    end

    def seed_entitlements!
      return unless defined?(BillingPlanEntitlement)

      plans = BillingPlan.subscription.active
      return if plans.empty?

      plans_by_tier = plans.group_by(&:tier)

      ExpertAdvisor.active.find_each do |expert_advisor|
        tiers = Array(expert_advisor.allowed_subscription_tiers).presence || plans_by_tier.keys
        tiers.each do |tier|
          Array(plans_by_tier[tier]).each do |plan|
            BillingPlanEntitlement.find_or_create_by!(
              billing_plan: plan,
              expert_advisor: expert_advisor
            )
          end
        end
      end
    end

    def plan_definition(tier:, interval:, interval_count:, amount_cents:, sort_order:)
      interval_key = Billing::IntervalLabeler.interval_key(interval: interval, interval_count: interval_count)
      {
        key: "#{tier}_#{interval_key}",
        name: "#{tier.to_s.humanize} #{Billing::IntervalLabeler.label(interval: interval, interval_count: interval_count)}",
        kind: "subscription",
        tier: tier,
        interval: interval,
        interval_count: interval_count,
        amount_cents: amount_cents,
        currency: DEFAULT_CURRENCY,
        active: true,
        sort_order: sort_order
      }
    end

    def stripe_configured?
      return true if ENV["STRIPE_PRIVATE_KEY"].present?

      Rails.logger.warn("Skipping billing plan seed because STRIPE_PRIVATE_KEY is not set.")
      false
    end
  end
end
