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

  module Courses
    module_function

    def definitions
      [
        {
          slug: "trading-foundations",
          position: 1,
          status: "published",
          category: "introduction",
          title_en: "Trading Foundations",
          title_es: "Fundamentos de Trading",
          summary_en: "Start here for platform setup, risk basics, and market structure.",
          summary_es: "Empieza con configuracion, riesgo basico y estructura de mercado.",
          description_en: "A quick start course for new traders to align on the workflow.",
          description_es: "Curso rapido para alinear el flujo de trabajo.",
          tiers: [],
          modules: [
            {
              title_en: "Welcome and Setup",
              title_es: "Bienvenida y Configuracion",
              summary_en: "Get ready to trade with the right defaults.",
              summary_es: "Prepara la plataforma con valores base.",
              lessons: [
                lesson_attrs(
                  title_en: "Platform Tour",
                  title_es: "Recorrido de la plataforma",
                  duration_seconds: 480,
                  stream_uid: "demo_stream_uid_1"
                ),
                lesson_attrs(
                  title_en: "Risk Basics",
                  title_es: "Riesgo basico",
                  duration_seconds: 540,
                  stream_uid: "demo_stream_uid_2"
                )
              ]
            },
            {
              title_en: "Market Basics",
              title_es: "Bases del mercado",
              summary_en: "Key concepts for reading structure.",
              summary_es: "Conceptos clave para leer estructura.",
              lessons: [
                lesson_attrs(
                  title_en: "Candlesticks 101",
                  title_es: "Velas 101",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_3"
                ),
                lesson_attrs(
                  title_en: "Trends and Structure",
                  title_es: "Tendencias y estructura",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_4"
                )
              ]
            }
          ]
        },
        {
          slug: "beginner-momentum",
          position: 2,
          status: "published",
          category: "beginner",
          title_en: "Beginner Momentum",
          title_es: "Momentum para principiantes",
          summary_en: "Build reliable entries with momentum rules.",
          summary_es: "Construye entradas confiables con reglas de momentum.",
          description_en: "Step-by-step drills for clean, repeatable momentum setups.",
          description_es: "Ejercicios para crear setups de momentum repetibles.",
          tiers: %w[basic],
          modules: [
            {
              title_en: "Momentum Essentials",
              title_es: "Esenciales de momentum",
              summary_en: "Understand momentum vs mean reversion.",
              summary_es: "Entiende momentum vs reversa.",
              lessons: [
                lesson_attrs(
                  title_en: "Momentum vs Mean Reversion",
                  title_es: "Momentum vs reversa",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_5"
                ),
                lesson_attrs(
                  title_en: "Entry Rules",
                  title_es: "Reglas de entrada",
                  duration_seconds: 540,
                  stream_uid: "demo_stream_uid_6"
                )
              ]
            },
            {
              title_en: "Execution",
              title_es: "Ejecucion",
              summary_en: "Convert signals into clean orders.",
              summary_es: "Convierte senales en ordenes limpias.",
              lessons: [
                lesson_attrs(
                  title_en: "Order Types",
                  title_es: "Tipos de orden",
                  duration_seconds: 480,
                  stream_uid: "demo_stream_uid_7"
                ),
                lesson_attrs(
                  title_en: "Position Sizing",
                  title_es: "Tamano de posicion",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_8"
                )
              ]
            }
          ]
        },
        {
          slug: "intermediate-systems",
          position: 3,
          status: "published",
          category: "intermediate",
          title_en: "Intermediate Systems",
          title_es: "Sistemas intermedios",
          summary_en: "Design and test structured trading systems.",
          summary_es: "Disena y prueba sistemas de trading.",
          description_en: "Refine strategies with filters, regimes, and testing.",
          description_es: "Refina estrategias con filtros y pruebas.",
          tiers: %w[hft],
          modules: [
            {
              title_en: "System Design",
              title_es: "Diseno de sistema",
              summary_en: "Build a consistent trading framework.",
              summary_es: "Construye un marco consistente.",
              lessons: [
                lesson_attrs(
                  title_en: "Strategy Filters",
                  title_es: "Filtros de estrategia",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_9"
                ),
                lesson_attrs(
                  title_en: "Regime Detection",
                  title_es: "Deteccion de regimen",
                  duration_seconds: 780,
                  stream_uid: "demo_stream_uid_10"
                )
              ]
            },
            {
              title_en: "Optimization",
              title_es: "Optimizacion",
              summary_en: "Tune for stability before live trading.",
              summary_es: "Ajusta para estabilidad antes de operar.",
              lessons: [
                lesson_attrs(
                  title_en: "Parameter Tuning",
                  title_es: "Ajuste de parametros",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_11"
                ),
                lesson_attrs(
                  title_en: "Walk Forward",
                  title_es: "Walk forward",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_12"
                )
              ]
            }
          ]
        },
        {
          slug: "advanced-risk-scaling",
          position: 4,
          status: "published",
          category: "advanced",
          title_en: "Advanced Risk and Scaling",
          title_es: "Riesgo avanzado y escalamiento",
          summary_en: "Scale safely with portfolio-level risk controls.",
          summary_es: "Escala de forma segura con control de riesgo.",
          description_en: "Advanced techniques for multi-account growth.",
          description_es: "Tecnicas avanzadas para crecimiento multi cuenta.",
          tiers: %w[pro],
          modules: [
            {
              title_en: "Portfolio Risk",
              title_es: "Riesgo de portafolio",
              summary_en: "Manage exposure across systems.",
              summary_es: "Administra exposicion entre sistemas.",
              lessons: [
                lesson_attrs(
                  title_en: "Correlation Control",
                  title_es: "Control de correlacion",
                  duration_seconds: 840,
                  stream_uid: "demo_stream_uid_13"
                ),
                lesson_attrs(
                  title_en: "Drawdown Rules",
                  title_es: "Reglas de drawdown",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_14"
                )
              ]
            },
            {
              title_en: "Scaling",
              title_es: "Escalamiento",
              summary_en: "Grow carefully with automation.",
              summary_es: "Crece con cuidado y automatizacion.",
              lessons: [
                lesson_attrs(
                  title_en: "Multi-Account Scaling",
                  title_es: "Escalamiento multi cuenta",
                  duration_seconds: 780,
                  stream_uid: "demo_stream_uid_15"
                ),
                lesson_attrs(
                  title_en: "Automation Safety",
                  title_es: "Seguridad de automatizacion",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_16"
                )
              ]
            }
          ]
        }
      ]
    end

    def seed_courses!
      return unless defined?(Course)

      definitions.each do |attrs|
        upsert_course(attrs.dup)
      end
    end

    def upsert_course(attrs)
      module_defs = attrs.delete(:modules) || []
      tiers = attrs.delete(:tiers) || []

      record = Course.find_or_initialize_by(slug: attrs[:slug])
      record.assign_attributes(attrs)
      record.published_at ||= Time.current if record.status == "published"
      record.save!

      upsert_modules(record, module_defs)
      attach_entitlements(record, tiers)
      record
    end

    def lesson_attrs(title_en:, title_es:, duration_seconds:, stream_uid: nil)
      {
        title_en: title_en,
        title_es: title_es,
        duration_seconds: duration_seconds,
        stream_uid: stream_uid,
        summary_en: "",
        summary_es: "",
        body_markdown_en: "# #{title_en}\n\n- Key idea\n- Checklist",
        body_markdown_es: "# #{title_es}\n\n- Idea clave\n- Checklist"
      }
    end

    def upsert_modules(course, module_defs)
      module_defs.each_with_index do |mod_attrs, index|
        lesson_defs = mod_attrs.delete(:lessons) || []
        module_record = course.course_modules.find_or_initialize_by(title_en: mod_attrs[:title_en])
        module_record.assign_attributes(mod_attrs)
        module_record.position = index
        module_record.save!

        upsert_lessons(module_record, lesson_defs)
      end
    end

    def upsert_lessons(course_module, lesson_defs)
      lesson_defs.each_with_index do |lesson_attrs, index|
        lesson_record = course_module.course_lessons.find_or_initialize_by(title_en: lesson_attrs[:title_en])
        lesson_record.assign_attributes(lesson_attrs)
        lesson_record.position = index
        lesson_record.save!
      end
    end

    def attach_entitlements(course, tiers)
      return if tiers.blank?
      return unless defined?(BillingPlan)

      plans = BillingPlan.subscription.active
      return if plans.empty?

      plans_by_tier = plans.group_by(&:tier)
      Array(tiers).each do |tier|
        Array(plans_by_tier[tier]).each do |plan|
          CoursePlanEntitlement.find_or_create_by!(course: course, billing_plan: plan)
        end
      end
    end

    def seed_progress_for(user:)
      return unless user
      return unless defined?(Courses::ProgressTracker)

      intro_course = Course.find_by(slug: "trading-foundations")
      intro_lesson = intro_course&.course_lessons&.first
      if intro_lesson
        Courses::ProgressTracker.new(
          user: user,
          lesson: intro_lesson,
          progress_seconds: (intro_lesson.duration_seconds.to_i * 0.5).to_i,
          completed: false
        ).call
      end

      basic_course = Course.find_by(slug: "beginner-momentum")
      completed_lessons = basic_course&.course_lessons&.first(2) || []
      completed_lessons.each do |lesson|
        Courses::ProgressTracker.new(
          user: user,
          lesson: lesson,
          progress_seconds: lesson.duration_seconds.to_i,
          completed: true
        ).call
      end
    end
  end

  module BillingPlans
    module_function

    DEFAULT_CURRENCY = "usd"
    TIER_DEFINITIONS = [
      { tier: "basic", sort_order: 1, monthly_cents: 2000 },
      { tier: "hft", sort_order: 2, monthly_cents: 4000 },
      { tier: "pro", sort_order: 3, monthly_cents: 6000 },
      { tier: "elite", sort_order: 4, monthly_cents: 8000 },
      { tier: "enterprise", sort_order: 5, monthly_cents: 10_000 }
    ].freeze
    INTERVAL_DEFINITIONS = [
      { interval: "day", interval_count: 1, multiplier: (12.0 / 365) },
      { interval: "week", interval_count: 1, multiplier: (12.0 / 52) },
      { interval: "month", interval_count: 1, multiplier: 1.0 },
      { interval: "year", interval_count: 1, multiplier: 9.0 }
    ].freeze

    def definitions
      TIER_DEFINITIONS.flat_map do |tier_def|
        INTERVAL_DEFINITIONS.map do |interval_def|
          amount = interval_amount(
            base_cents: tier_def[:monthly_cents],
            multiplier: interval_def[:multiplier]
          )
          plan_definition(
            tier: tier_def[:tier],
            interval: interval_def[:interval],
            interval_count: interval_def[:interval_count],
            amount_cents: amount,
            sort_order: tier_def[:sort_order]
          )
        end
      end
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

    def interval_amount(base_cents:, multiplier:)
      amount = (base_cents * multiplier).round
      amount.positive? ? amount : 1
    end

    def stripe_configured?
      return true if ENV["STRIPE_PRIVATE_KEY"].present?

      Rails.logger.warn("Skipping billing plan seed because STRIPE_PRIVATE_KEY is not set.")
      false
    end
  end

  module MarketplaceProducts
    module_function

    def definitions
      [
        {
          slug: "ea_starter_bundle",
          sort_order: 1,
          title_en: "EA Starter Bundle",
          title_es: "Bundle inicial de EAs",
          summary_en: "Own the core EAs with lifetime access for your trading workflows.",
          summary_es: "Acceso de por vida a los EAs principales para tus flujos de trading.",
          description_en: "A one-time bundle that includes the flagship Expert Advisors and lifetime access.",
          description_es: "Bundle de compra unica con los Expert Advisors principales y acceso de por vida.",
          amount_cents: 12_900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-01.jpg"),
          ea_ids: %w[sniper_advanced_panel pandora_box],
          course_slugs: []
        },
        {
          slug: "course_essentials",
          sort_order: 2,
          title_en: "Course Essentials Bundle",
          title_es: "Bundle esencial de cursos",
          summary_en: "Build your trading foundation with lifetime access to core courses.",
          summary_es: "Refuerza tu base de trading con acceso de por vida a cursos clave.",
          description_en: "One-time access to the foundational courses plus future updates in this bundle.",
          description_es: "Acceso unico a los cursos fundamentales con actualizaciones futuras del bundle.",
          amount_cents: 8_900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-09.jpg"),
          ea_ids: [],
          course_slugs: %w[trading-foundations beginner-momentum]
        },
        {
          slug: "pro_trader_bundle",
          sort_order: 3,
          title_en: "Pro Trader Bundle",
          title_es: "Bundle Pro Trader",
          summary_en: "Combine premium EAs and courses for a full-stack trading kit.",
          summary_es: "Combina EAs premium y cursos para un kit completo de trading.",
          description_en: "A mixed bundle for traders who want both automation tools and advanced training.",
          description_es: "Bundle mixto para traders que buscan automatizacion y entrenamiento avanzado.",
          amount_cents: 17_900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-17.jpg"),
          ea_ids: %w[sniper_advanced_panel],
          course_slugs: %w[intermediate-systems]
        }
      ]
    end

    def seed_products!
      return unless defined?(MarketplaceProduct)
      return unless defined?(BillingPlan)
      unless ENV["STRIPE_PRIVATE_KEY"].present?
        Rails.logger.warn("[Seeds::MarketplaceProducts] skipped: STRIPE_PRIVATE_KEY is not set")
        return
      end

      manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: true)

      definitions.each do |attrs|
        upsert_product(manager, attrs)
      end
    end

    def upsert_product(manager, attrs)
      product = manager.upsert!(
        product_attributes: {
          slug: attrs[:slug],
          status: "active",
          sort_order: attrs[:sort_order],
          title_en: attrs[:title_en],
          title_es: attrs[:title_es],
          summary_en: attrs[:summary_en],
          summary_es: attrs[:summary_es],
          description_en: attrs[:description_en],
          description_es: attrs[:description_es]
        },
        plan_attributes: {
          amount_cents: attrs[:amount_cents],
          currency: BillingPlans::DEFAULT_CURRENCY
        }
      )

      attach_image(product, attrs[:image])
      attach_entitlements(product.billing_plan, attrs[:ea_ids], attrs[:course_slugs])
    end

    def attach_image(product, image_path)
      return unless image_path&.exist?
      return if product.image.attached?

      File.open(image_path) do |file|
        product.image.attach(
          io: file,
          filename: File.basename(image_path),
          content_type: "image/jpeg"
        )
      end
    end

    def attach_entitlements(plan, ea_ids, course_slugs)
      Array(ea_ids).each do |ea_id|
        expert_advisor = ExpertAdvisor.find_by(ea_id: ea_id)
        next unless expert_advisor

        BillingPlanEntitlement.find_or_create_by!(
          billing_plan: plan,
          expert_advisor: expert_advisor
        )
      end

      Array(course_slugs).each do |slug|
        course = Course.find_by(slug: slug)
        next unless course

        CoursePlanEntitlement.find_or_create_by!(
          billing_plan: plan,
          course: course
        )
      end
    end
  end

  module Addons
    module_function

    def definitions
      [
        {
          key: "sniper_panel_news_filter",
          slug: "addon_sniper_news_filter",
          sort_order: 10,
          title_en: "News Filter Add-on",
          title_es: "Add-on Filtro de Noticias",
          summary_en: "Block EA entries during high-impact news windows.",
          summary_es: "Bloquea entradas del EA durante noticias de alto impacto.",
          description_en: "A paid add-on for the Sniper Advanced Panel that adds a configurable news filter.",
          description_es: "Add-on de pago para Sniper Advanced Panel con filtro de noticias configurable.",
          amount_cents: 2900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-02.jpg"),
          addonable_type: "ExpertAdvisor",
          addonable_key: "sniper_advanced_panel"
        },
        {
          key: "pandora_risk_guard",
          slug: "addon_pandora_risk_guard",
          sort_order: 11,
          title_en: "Risk Guard Add-on",
          title_es: "Add-on Guardia de Riesgo",
          summary_en: "Adds drawdown and volatility safeguards to Pandora Box.",
          summary_es: "Agrega protecciones de drawdown y volatilidad a Pandora Box.",
          description_en: "A paid add-on for Pandora Box that introduces dynamic risk guardrails.",
          description_es: "Add-on de pago para Pandora Box con protecciones dinámicas de riesgo.",
          amount_cents: 3900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-06.jpg"),
          addonable_type: "ExpertAdvisor",
          addonable_key: "pandora_box"
        },
        {
          key: "foundations_workbook",
          slug: "addon_foundations_workbook",
          sort_order: 12,
          title_en: "Foundations Workbook",
          title_es: "Workbook Fundamentos",
          summary_en: "Downloadable worksheets for the Trading Foundations course.",
          summary_es: "Hojas descargables para el curso Fundamentos de Trading.",
          description_en: "A paid add-on with printable exercises and checklists.",
          description_es: "Add-on de pago con ejercicios y listas imprimibles.",
          amount_cents: 1900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-12.jpg"),
          addonable_type: "Course",
          addonable_key: "trading-foundations"
        }
      ]
    end

    def seed_addons!
      return unless defined?(Addon)
      return unless defined?(MarketplaceProduct)
      return unless defined?(BillingPlan)
      unless ENV["STRIPE_PRIVATE_KEY"].present?
        Rails.logger.warn("[Seeds::Addons] skipped: STRIPE_PRIVATE_KEY is not set")
        return
      end

      manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: true)

      definitions.each do |attrs|
        addonable = resolve_addonable(attrs)
        next unless addonable

        product = manager.upsert!(
          product_attributes: {
            slug: attrs[:slug],
            status: "active",
            sort_order: attrs[:sort_order],
            title_en: attrs[:title_en],
            title_es: attrs[:title_es],
            summary_en: attrs[:summary_en],
            summary_es: attrs[:summary_es],
            description_en: attrs[:description_en],
            description_es: attrs[:description_es]
          },
          plan_attributes: {
            amount_cents: attrs[:amount_cents],
            currency: BillingPlans::DEFAULT_CURRENCY
          }
        )

        MarketplaceProducts.attach_image(product, attrs[:image])
        upsert_addon(attrs, product.billing_plan, addonable)
      end
    end

    def resolve_addonable(attrs)
      case attrs[:addonable_type]
      when "ExpertAdvisor"
        ExpertAdvisor.find_by(ea_id: attrs[:addonable_key])
      when "Course"
        Course.find_by(slug: attrs[:addonable_key])
      end
    end

    def upsert_addon(attrs, plan, addonable)
      addon = Addon.find_or_initialize_by(key: attrs[:key])
      addon.billing_plan = plan
      addon.addonable = addonable
      addon.metadata = (addon.metadata || {}).to_h.merge("seed_key" => attrs[:key])
      addon.save!

      plan.metadata = (plan.metadata || {}).to_h.merge(
        "addon_key" => addon.key,
        "addonable_type" => addonable.class.name,
        "addonable_id" => addonable.id
      )
      plan.save!
    end
  end

  module ExpertAdvisorBundles
    module_function

    def seed_bundles!
      return unless defined?(ExpertAdvisorBundle)
      return unless defined?(ExpertAdvisor)

      bundle_path = Rails.root.join("db", "seeds", "fixtures", "ea_bundle.rar")
      unless bundle_path.exist?
        Rails.logger.warn("[Seeds::ExpertAdvisorBundles] skipped: bundle fixture missing")
        return
      end

      ExpertAdvisor.find_each do |expert_advisor|
        seed_base_bundle(expert_advisor, bundle_path)
        seed_addon_bundles(expert_advisor, bundle_path)
      end
    end

    def seed_base_bundle(expert_advisor, bundle_path)
      bundle = ExpertAdvisorBundle.find_or_initialize_by(expert_advisor: expert_advisor, bundle_key: "base")
      bundle.required_addon_keys = ""
      bundle.active = true if bundle.active.nil?
      bundle.save!

      attach_bundle(bundle, bundle_path, "#{expert_advisor.ea_id}__base.rar")
    end

    def seed_addon_bundles(expert_advisor, bundle_path)
      addon_keys = expert_advisor.addons.order(:key).pluck(:key)
      addon_combinations(addon_keys).each do |combo|
        bundle_key = combo.join("__")
        bundle = ExpertAdvisorBundle.find_or_initialize_by(expert_advisor: expert_advisor, bundle_key: bundle_key)
        bundle.required_addon_keys = combo.join(",")
        bundle.active = true if bundle.active.nil?
        bundle.save!

        attach_bundle(bundle, bundle_path, "#{expert_advisor.ea_id}__#{bundle_key}.rar")
      end
    end

    def attach_bundle(bundle, bundle_path, filename)
      return if bundle.bundle_file.attached?

      File.open(bundle_path) do |file|
        bundle.bundle_file.attach(
          io: file,
          filename: filename,
          content_type: "application/x-rar-compressed"
        )
      end
    end

    def addon_combinations(addon_keys)
      keys = addon_keys.sort
      (1..keys.size).flat_map { |size| keys.combination(size).to_a }
    end
  end

  module QaUsers
    module_function

    DEFAULT_PASSWORD = "Password123!"
    DEFAULT_TRADER_EMAIL = "qa@example.com"
    DEFAULT_PARTNER_EMAIL = "qa.partner@example.com"

    def seed!(trader_email: DEFAULT_TRADER_EMAIL, partner_email: DEFAULT_PARTNER_EMAIL, password: DEFAULT_PASSWORD)
      return {} unless defined?(User)

      {
        trader: upsert_user(email: trader_email, name: "QA User", role: :trader, password: password),
        partner: upsert_user(email: partner_email, name: "QA Partner", role: :partner, password: password)
      }
    end

    def upsert_user(email:, name:, role:, password:)
      user = User.find_or_initialize_by(email: email)
      user.name = name if user.name.blank?
      user.role = role if user.role.to_s != role.to_s
      user.terms_accepted_at ||= Time.current
      if user.new_record?
        user.password = password
        user.password_confirmation = password
      end
      user.save!
      user
    end
  end

  module Partners
    module_function

    DEFAULT_REFERRED_EMAILS = [
      "qa.referral1@example.com",
      "qa.referral2@example.com",
      "qa.referral3@example.com"
    ].freeze
    DEFAULT_PASSWORD = QaUsers::DEFAULT_PASSWORD
    DEFAULT_DISCOUNT_PERCENT = 15

    def seed_qa!(partner:, referred_emails: DEFAULT_REFERRED_EMAILS, password: DEFAULT_PASSWORD)
      return [] unless partner&.partner?
      return [] unless defined?(PartnerProfile) && defined?(PartnerMembership)
      return [] unless defined?(PartnerCommission) && defined?(PartnerPayoutRequest)
      return [] unless defined?(Refer)

      partner.ensure_referral_code
      partner.ensure_partner_profile_for_partner
      profile = partner.partner_profile
      return [] unless profile

      if profile.discount_percent.nil? || profile.discount_percent.zero?
        profile.update!(discount_percent: DEFAULT_DISCOUNT_PERCENT)
      end

      requested_commissions = []
      paid_commissions = []
      referred_users = []

      referred_emails.each_with_index do |email, idx|
        user = QaUsers.upsert_user(
          email: email,
          name: "QA Referral #{idx + 1}",
          role: :trader,
          password: password
        )
        referred_users << user

        attach_referral(partner, user)
        membership = upsert_membership(profile, user, depth: idx + 1)
        seed_commissions(
          profile: profile,
          membership: membership,
          user: user,
          index: idx,
          requested_commissions: requested_commissions,
          paid_commissions: paid_commissions
        )
      end

      seed_subscription_for(referred_users.first)
      attach_payout_request(
        profile,
        key: "seed:qa_partner_requested",
        status: :pending,
        requested_at: 5.days.ago,
        commissions: requested_commissions,
        commission_status: :requested
      )
      attach_payout_request(
        profile,
        key: "seed:qa_partner_paid",
        status: :paid,
        paid_at: 1.month.ago,
        commissions: paid_commissions,
        commission_status: :paid
      )

      referred_users
    end

    def attach_referral(partner, user)
      return unless user.respond_to?(:referrer)
      return if user.referrer == partner
      return if user.referrer.present? && user.referrer != partner

      code = partner.referral_codes.first&.code
      return if code.blank?

      Refer.refer(code: code, referee: user)
      user.reload
      user.ensure_referral_code_if_referred!
    end

    def upsert_membership(profile, user, depth:)
      membership = PartnerMembership.active.find_or_initialize_by(user: user)
      membership.partner_profile = profile
      membership.referral = user.referral if user.respond_to?(:referral)
      membership.depth = depth if membership.depth.to_i <= 0
      membership.started_at ||= Time.current
      membership.save!
      membership
    end

    def seed_commissions(profile:, membership:, user:, index:, requested_commissions:, paid_commissions:)
      now = Time.current
      base_key = "seed:qa_partner_#{user.id || user.email}"

      upsert_commission(
        profile: profile,
        membership: membership,
        user: user,
        seed_key: "#{base_key}:pending",
        status: :pending,
        commission_kind: :initial,
        amount_cents: 1200 + (index * 200),
        occurred_at: now - (index + 2).days
      )

      if index.zero?
        requested_commissions << upsert_commission(
          profile: profile,
          membership: membership,
          user: user,
          seed_key: "#{base_key}:requested",
          status: :requested,
          commission_kind: :renewal,
          amount_cents: 900,
          occurred_at: now - 10.days
        )
      elsif index == 1
        paid_commissions << upsert_commission(
          profile: profile,
          membership: membership,
          user: user,
          seed_key: "#{base_key}:paid",
          status: :paid,
          commission_kind: :renewal,
          amount_cents: 1500,
          occurred_at: now - 2.months
        )
      end
    end

    def upsert_commission(profile:, membership:, user:, seed_key:, status:, commission_kind:, amount_cents:, occurred_at:)
      commission = PartnerCommission.find_by("metadata ->> 'seed_key' = ?", seed_key)
      attrs = {
        partner_profile: profile,
        partner_membership: membership,
        referred_user: user,
        referral: user.respond_to?(:referral) ? user.referral : nil,
        commission_kind: commission_kind,
        amount_cents: amount_cents,
        currency: "usd",
        percent_applied: profile.discount_percent_or_default,
        status: status,
        occurred_at: occurred_at,
        metadata: seed_metadata(seed_key)
      }

      if commission
        commission.update!(attrs)
      else
        commission = PartnerCommission.create!(attrs)
      end

      commission
    end

    def seed_metadata(seed_key)
      { "seed_key" => seed_key, "seed_source" => "qa" }
    end

    def attach_payout_request(profile, key:, status:, commissions:, commission_status:, requested_at: nil, paid_at: nil)
      return if commissions.blank?

      request = PartnerPayoutRequest.find_or_initialize_by(
        partner_profile: profile,
        payment_reference: key
      )
      request.status = status
      request.note ||= "Seed data"
      request.requested_at ||= requested_at if requested_at
      request.paid_at = paid_at if paid_at
      request.total_cents = commissions.sum(&:amount_cents)
      request.save!

      commissions.each do |commission|
        commission.update!(payout_request: request, status: commission_status)
      end

      request
    end

    def seed_subscription_for(user)
      return unless user
      return unless defined?(Pay::Customer) && defined?(Pay::Subscription)

      customer = user.pay_customers.find_or_initialize_by(processor: "stripe")
      customer.processor_id ||= "cus_seed_#{user.id}"
      customer.default = true if customer.default.nil?
      customer.save!

      subscription = customer.subscriptions.find_or_initialize_by(processor_id: "sub_seed_#{user.id}")
      subscription.name ||= "default"
      subscription.processor_plan ||= "seed_basic_monthly"
      subscription.status = "active"
      subscription.quantity ||= 1
      subscription.current_period_start ||= 15.days.ago
      subscription.current_period_end ||= 15.days.from_now
      subscription.save!
    end
  end
end
