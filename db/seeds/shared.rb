profiles_seed_path = Rails.root.join("db", "seeds", "profiles.rb")
load(profiles_seed_path) if !defined?(Seeds::Profiles) && profiles_seed_path.exist?
require "base64"
require "digest/md5"

module Seeds
  module ExpertAdvisors
    module_function

    INTRO_VIDEO_TOKEN = "[[video:docs/videos/video.mp4]]"
    OUTRO_YOUTUBE_TOKEN = "[[youtube:https://www.youtube.com/watch?v=dQw4w9WgXcQ]]"
    DEFAULT_GUIDE_EA_ID = "sniper_advanced_panel".freeze
    GUIDE_PATHS = {
      "sniper_advanced_panel" => {
        en: [
          Rails.root.join("docs_eas", "sniper_advanced_panel", "sniper_advanced_panel_guide_en.md"),
          Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_EN.md")
        ],
        es: [
          Rails.root.join("docs_eas", "sniper_advanced_panel", "sniper_advanced_panel_guide_es.md"),
          Rails.root.join("docs_eas", "sniper_advanced_panel", "Manual_ES.md")
        ]
      },
      "pandora_box" => {
        en: [
          Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_guide_en.md")
        ],
        es: [
          Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_guide_es.md")
        ]
      },
      "fibonacci_elite" => {
        en: [
          Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_copy", "en", "base-ea.md")
        ],
        es: [
          Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_copy", "es", "base-ea.md")
        ]
      }
    }.freeze

    def guide_for(ea_id:, locale:, profile: Seeds::Profiles.current)
      @guide_cache ||= {}
      key = [ea_id.to_s, locale.to_s, profile.to_s]
      @guide_cache[key] ||= begin
        path = guide_path(ea_id: ea_id, locale: locale)
        content = path.exist? ? File.read(path) : ""
        profile.to_s == Seeds::Profiles::PROD_MIRROR ? content : inject_media_tokens(content)
      end
    end

    def manual_en(profile: Seeds::Profiles.current)
      guide_for(ea_id: DEFAULT_GUIDE_EA_ID, locale: :en, profile: profile)
    end

    def manual_es(profile: Seeds::Profiles.current)
      guide_for(ea_id: DEFAULT_GUIDE_EA_ID, locale: :es, profile: profile)
    end

    def core_definitions(profile: Seeds::Profiles.current)
      [ pandora_definition(profile: profile) ]
    end

    def prune_for_profile!(profile: Seeds::Profiles.current)
      return unless defined?(ExpertAdvisor)

      keep_ids = core_definitions(profile: profile).map { |attrs| attrs[:ea_id] }

      ExpertAdvisor.unscoped.where.not(ea_id: keep_ids).where(deleted_at: nil).update_all(
        deleted_at: Time.current,
        updated_at: Time.current
      )
    end

    def prod_mirror_definitions(profile: Seeds::Profiles.current)
      [ pandora_definition(profile: profile) ]
    end

    def full_qa_definitions(profile: Seeds::Profiles.current)
      [ pandora_definition(profile: profile) ]
    end

    def qa_definitions(profile: Seeds::Profiles.current)
      []
    end

    def pandora_definition(profile: Seeds::Profiles.current)
      {
        name: "PANDORA BOX EA",
        tier_rank: 1,
        ea_id: "pandora_box",
        description: "Breakout EA for MT5 with configurable direction modes and grid controls.",
        ea_type: :ea_robot,
        trial_enabled: false,
        allowed_subscription_tiers: [ Billing::PandoraPricing::TIER ],
        doc_guide_en: guide_for(ea_id: "pandora_box", locale: :en, profile: profile),
        doc_guide_es: guide_for(ea_id: "pandora_box", locale: :es, profile: profile),
        tags: %w[automation breakout]
      }
    end

    def upsert_expert_advisor(attrs, bundle_path: nil)
      allowed_tiers = attrs.delete(:allowed_subscription_tiers)
      tags = attrs.delete(:tags)

      record = ExpertAdvisor.unscoped.find_or_initialize_by(ea_id: attrs[:ea_id])
      record.assign_attributes(attrs)
      record.allowed_subscription_tiers = allowed_tiers
      record.tag_list = Array(tags).map(&:to_s) if tags
      record.deleted_at = nil
      record.save!

      attach_bundle(record, bundle_path) if bundle_path
      record
    end

    def attach_bundle(record, bundle_path)
      return unless bundle_path&.exist?

      extension = File.extname(bundle_path.to_s)
      filename = "#{record.ea_id}#{extension.presence || ".zip"}"
      source_checksum = bundle_checksum(bundle_path)

      if record.ea_files.attached?
        blob = record.ea_files.blob
        if blob.checksum == source_checksum
          blob.update!(filename: filename) if blob.filename.to_s != filename
          record.ensure_bundle_filename!
          return
        end

        Rails.logger.info("[Seeds::ExpertAdvisors] replacing EA bundle for ea_id=#{record.ea_id} (checksum changed)")
        record.ea_files.purge
      end

      File.open(bundle_path) do |file|
        record.ea_files.attach(
          io: file,
          filename: filename,
          content_type: bundle_content_type(bundle_path)
        )
      end

      record.ensure_bundle_filename!
    end

    def bundle_checksum(bundle_path)
      Base64.strict_encode64(Digest::MD5.file(bundle_path).digest)
    end

    def bundle_content_type(bundle_path)
      case File.extname(bundle_path.to_s).downcase
      when ".zip"
        "application/zip"
      when ".rar"
        "application/x-rar-compressed"
      else
        "application/octet-stream"
      end
    end

    def guide_path(ea_id:, locale:)
      locale_key = locale.to_s == "es" ? :es : :en
      configured_paths = GUIDE_PATHS.dig(ea_id.to_s, locale_key)
      configured_paths ||= GUIDE_PATHS.dig(DEFAULT_GUIDE_EA_ID, locale_key)
      first_existing_path(*Array(configured_paths))
    end

    def bundle_path_for(ea_id)
      return unless ea_id.to_s == "pandora_box"

      first_existing_path(
        Rails.root.join("docs_eas", "pandora_box_ea", "PANDORA_BOX_EA.zip"),
        Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.zip"),
        Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea.rar")
      )
    end

    def first_existing_path(*paths)
      paths.find(&:exist?) || paths.first
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
          tags: %w[foundations basics],
          tiers: %w[basic],
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
          tags: %w[momentum entries],
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
          tags: %w[systems automation],
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
          tags: %w[risk portfolio],
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
        },
        {
          slug: "price-action-sets",
          position: 5,
          status: "published",
          category: "beginner",
          title_en: "Price Action Sets",
          title_es: "Setups de accion del precio",
          summary_en: "Read structure and timing with clear price action patterns.",
          summary_es: "Lee estructura y timing con patrones claros de precio.",
          description_en: "Pattern-based entries built on clean structure and market context.",
          description_es: "Entradas por patrones con estructura y contexto.",
          tags: %w[price_action patterns],
          tiers: %w[basic],
          modules: [
            {
              title_en: "Structure Basics",
              title_es: "Bases de estructura",
              summary_en: "Define swing points and usable zones.",
              summary_es: "Define swings y zonas operables.",
              lessons: [
                lesson_attrs(
                  title_en: "Swing Points",
                  title_es: "Puntos de swing",
                  duration_seconds: 540,
                  stream_uid: "demo_stream_uid_17"
                ),
                lesson_attrs(
                  title_en: "Range Breaks",
                  title_es: "Rupturas de rango",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_18"
                )
              ]
            },
            {
              title_en: "Entry Patterns",
              title_es: "Patrones de entrada",
              summary_en: "Identify high-probability triggers.",
              summary_es: "Identifica gatillos de alta probabilidad.",
              lessons: [
                lesson_attrs(
                  title_en: "Break and Retest",
                  title_es: "Ruptura y retesteo",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_19"
                ),
                lesson_attrs(
                  title_en: "Failed Breakouts",
                  title_es: "Falsas rupturas",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_20"
                )
              ]
            }
          ]
        },
        {
          slug: "orderflow-lab",
          position: 6,
          status: "published",
          category: "intermediate",
          title_en: "Orderflow Lab",
          title_es: "Laboratorio de orderflow",
          summary_en: "Map liquidity and validate entries with flow data.",
          summary_es: "Mapea liquidez y valida entradas con flujo.",
          description_en: "Applied orderflow practice for timing and liquidity insight.",
          description_es: "Practica aplicada de orderflow para timing y liquidez.",
          tags: %w[orderflow liquidity],
          tiers: [],
          modules: [
            {
              title_en: "Tape Reading",
              title_es: "Lectura de cinta",
              summary_en: "See pressure shifts before the move.",
              summary_es: "Detecta cambios de presion antes del movimiento.",
              lessons: [
                lesson_attrs(
                  title_en: "Imbalance Clues",
                  title_es: "Pistas de desequilibrio",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_21"
                ),
                lesson_attrs(
                  title_en: "Absorption",
                  title_es: "Absorcion",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_22"
                )
              ]
            },
            {
              title_en: "Liquidity Mapping",
              title_es: "Mapa de liquidez",
              summary_en: "Track pools and reaction zones.",
              summary_es: "Rastrea pools y zonas de reaccion.",
              lessons: [
                lesson_attrs(
                  title_en: "Liquidity Sweeps",
                  title_es: "Barridos de liquidez",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_23"
                ),
                lesson_attrs(
                  title_en: "Flow Confirmation",
                  title_es: "Confirmacion de flujo",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_24"
                )
              ]
            }
          ]
        },
        {
          slug: "macro-structure",
          position: 7,
          status: "published",
          category: "intermediate",
          title_en: "Macro Structure",
          title_es: "Estructura macro",
          summary_en: "Align intraday tactics with macro drivers.",
          summary_es: "Alinea tacticas intradia con drivers macro.",
          description_en: "Frameworks for macro regimes, narratives, and timing.",
          description_es: "Frameworks para regimenes macro, narrativas y timing.",
          tags: %w[macro fundamentals],
          tiers: %w[hft],
          modules: [
            {
              title_en: "Macro Drivers",
              title_es: "Drivers macro",
              summary_en: "Rate cycles and liquidity shifts.",
              summary_es: "Ciclos de tasas y cambios de liquidez.",
              lessons: [
                lesson_attrs(
                  title_en: "Rate Cycles",
                  title_es: "Ciclos de tasas",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_25"
                ),
                lesson_attrs(
                  title_en: "Risk On Risk Off",
                  title_es: "Riesgo on riesgo off",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_26"
                )
              ]
            },
            {
              title_en: "News Filters",
              title_es: "Filtros de noticias",
              summary_en: "Prepare for key events.",
              summary_es: "Prepara eventos clave.",
              lessons: [
                lesson_attrs(
                  title_en: "Event Windows",
                  title_es: "Ventanas de evento",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_27"
                ),
                lesson_attrs(
                  title_en: "Correlation Map",
                  title_es: "Mapa de correlacion",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_28"
                )
              ]
            }
          ]
        },
        {
          slug: "algorithmic-execution",
          position: 8,
          status: "published",
          category: "advanced",
          title_en: "Algorithmic Execution",
          title_es: "Ejecucion algoritmica",
          summary_en: "Translate strategies into automated execution.",
          summary_es: "Traduce estrategias a ejecucion automatizada.",
          description_en: "Design signals, validate them, and deploy safely.",
          description_es: "Disena senales, valida y despliega con seguridad.",
          tags: %w[automation execution],
          tiers: %w[pro],
          modules: [
            {
              title_en: "Signal Engineering",
              title_es: "Ingenieria de senales",
              summary_en: "Define rules without ambiguity.",
              summary_es: "Define reglas sin ambiguedad.",
              lessons: [
                lesson_attrs(
                  title_en: "Rule Translation",
                  title_es: "Traduccion de reglas",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_29"
                ),
                lesson_attrs(
                  title_en: "Signal Validation",
                  title_es: "Validacion de senales",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_30"
                )
              ]
            },
            {
              title_en: "Execution",
              title_es: "Ejecucion",
              summary_en: "Protect against slippage and drift.",
              summary_es: "Protege contra slippage y drift.",
              lessons: [
                lesson_attrs(
                  title_en: "Order Routing",
                  title_es: "Ruteo de ordenes",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_31"
                ),
                lesson_attrs(
                  title_en: "Slippage Control",
                  title_es: "Control de slippage",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_32"
                )
              ]
            }
          ]
        },
        {
          slug: "psychology-discipline",
          position: 9,
          status: "published",
          category: "beginner",
          title_en: "Psychology and Discipline",
          title_es: "Psicologia y disciplina",
          summary_en: "Build routines that keep decisions consistent.",
          summary_es: "Crea rutinas para decisiones consistentes.",
          description_en: "Mindset systems for calm execution under pressure.",
          description_es: "Sistemas de mindset para ejecutar bajo presion.",
          tags: %w[psychology discipline],
          tiers: %w[basic],
          modules: [
            {
              title_en: "Mindset",
              title_es: "Mindset",
              summary_en: "Reduce noise before the session.",
              summary_es: "Reduce ruido antes de la sesion.",
              lessons: [
                lesson_attrs(
                  title_en: "Pre-Session Prep",
                  title_es: "Preparacion previa",
                  duration_seconds: 540,
                  stream_uid: "demo_stream_uid_33"
                ),
                lesson_attrs(
                  title_en: "Emotional Triggers",
                  title_es: "Disparadores emocionales",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_34"
                )
              ]
            },
            {
              title_en: "Process",
              title_es: "Proceso",
              summary_en: "Keep a tight execution loop.",
              summary_es: "Mantiene un bucle de ejecucion.",
              lessons: [
                lesson_attrs(
                  title_en: "Rules Journal",
                  title_es: "Diario de reglas",
                  duration_seconds: 600,
                  stream_uid: "demo_stream_uid_35"
                ),
                lesson_attrs(
                  title_en: "Consistency Loops",
                  title_es: "Loops de consistencia",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_36"
                )
              ]
            }
          ]
        },
        {
          slug: "portfolio-hedging",
          position: 10,
          status: "published",
          category: "advanced",
          title_en: "Portfolio Hedging",
          title_es: "Cobertura de portafolio",
          summary_en: "Balance exposure with systematic hedges.",
          summary_es: "Balancea exposicion con coberturas sistematicas.",
          description_en: "Protect capital through structured hedging plans.",
          description_es: "Protege capital con planes de cobertura.",
          tags: %w[portfolio risk],
          tiers: %w[pro],
          modules: [
            {
              title_en: "Exposure Control",
              title_es: "Control de exposicion",
              summary_en: "Quantify and cap correlated risk.",
              summary_es: "Cuantifica y limita riesgo correlacionado.",
              lessons: [
                lesson_attrs(
                  title_en: "Hedge Ratios",
                  title_es: "Ratios de cobertura",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_37"
                ),
                lesson_attrs(
                  title_en: "Correlation Bands",
                  title_es: "Bandas de correlacion",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_38"
                )
              ]
            },
            {
              title_en: "Scenario Planning",
              title_es: "Planeacion de escenarios",
              summary_en: "Stress-test exposure before it hurts.",
              summary_es: "Stress test de exposicion antes del dolor.",
              lessons: [
                lesson_attrs(
                  title_en: "Stress Tests",
                  title_es: "Stress tests",
                  duration_seconds: 720,
                  stream_uid: "demo_stream_uid_39"
                ),
                lesson_attrs(
                  title_en: "Capital Buckets",
                  title_es: "Buckets de capital",
                  duration_seconds: 660,
                  stream_uid: "demo_stream_uid_40"
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
      tags = attrs.delete(:tags)

      record = Course.find_or_initialize_by(slug: attrs[:slug])
      record.assign_attributes(attrs)
      record.tag_list = Array(tags).map(&:to_s) if tags
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

      price_course = Course.find_by(slug: "price-action-sets")
      price_lesson = price_course&.course_lessons&.first
      if price_lesson
        Courses::ProgressTracker.new(
          user: user,
          lesson: price_lesson,
          progress_seconds: (price_lesson.duration_seconds.to_i * 0.4).to_i,
          completed: false
        ).call
      end

      mindset_course = Course.find_by(slug: "psychology-discipline")
      mindset_lesson = mindset_course&.course_lessons&.first
      if mindset_lesson
        Courses::ProgressTracker.new(
          user: user,
          lesson: mindset_lesson,
          progress_seconds: (mindset_lesson.duration_seconds.to_i * 0.6).to_i,
          completed: true
        ).call
      end
    end
  end

  module BillingPlans
    module_function

    DEFAULT_CURRENCY = Billing::PandoraPricing::CURRENCY
    LOCAL_PRODUCT_ID = "seed_product_pandora_box".freeze

    def definitions(profile: Seeds::Profiles.current)
      Billing::PandoraPricing::PLAN_DEFINITIONS.map.with_index do |(key, pricing), index|
        interval_label = Billing::IntervalLabeler.label(
          interval: pricing.fetch(:interval),
          interval_count: pricing.fetch(:interval_count)
        )
        {
          key: key,
          name: "#{Billing::PandoraPricing::PRODUCT_NAME} #{interval_label}",
          description: "Pandora Box EA recurring subscription.",
          kind: "subscription",
          tier: Billing::PandoraPricing::TIER,
          interval: pricing.fetch(:interval),
          interval_count: pricing.fetch(:interval_count),
          amount_cents: pricing.fetch(:amount_cents),
          currency: DEFAULT_CURRENCY,
          active: true,
          sort_order: index + 1,
          metadata: { "catalog_product" => "pandora_box" },
          stripe_product_name: Billing::PandoraPricing::PRODUCT_NAME
        }
      end
    end

    def seed_plans!(allow_local: false, profile: Seeds::Profiles.current, retire_superseded_prices: true)
      return seed_local_plans!(profile: profile) if allow_local && Rails.env.test?

      if stripe_seeding_enabled?
        return unless defined?(Billing::PlanCreator)

        shared_product_id = nil
        return definitions(profile: profile).map do |definition|
          attrs = definition.dup
          attrs[:stripe_product_id] = shared_product_id if shared_product_id.present?
          result = Billing::PlanCreator.new(
            attrs,
            retire_superseded_prices: retire_superseded_prices
          ).call
          shared_product_id ||= result.product.id
          result.plan
        end
      end

      return unless allow_local

      seed_local_plans!(profile: profile)
    end

    def seed_local_plans!(profile: Seeds::Profiles.current)
      return unless defined?(BillingPlan)

      definitions(profile: profile).map { |attrs| upsert_local_plan(attrs) }
    end

    def prune_for_profile!(profile: Seeds::Profiles.current)
      return unless defined?(BillingPlan)

      keep_keys = definitions(profile: profile).map { |attrs| attrs[:key] }
      return if keep_keys.empty?

      BillingPlan.subscription.where.not(key: keep_keys).where(active: true).update_all(
        active: false,
        updated_at: Time.current
      )
    end

    def prune_entitlements!(billing_plan_ids:, expert_advisor_ids:)
      return unless defined?(BillingPlanEntitlement)
      return if billing_plan_ids.blank? || expert_advisor_ids.blank?

      BillingPlanEntitlement.where.not(billing_plan_id: billing_plan_ids).delete_all
      BillingPlanEntitlement.where.not(expert_advisor_id: expert_advisor_ids).delete_all
    end

    def upsert_local_plan(attrs)
      plan_attrs = attrs.except(:stripe_product_name)
      price_id = "seed_price_#{attrs.fetch(:key)}_#{attrs.fetch(:amount_cents)}"
      now = Time.current

      BillingPlan.transaction do
        plan = BillingPlan.find_or_initialize_by(key: attrs.fetch(:key))
        plan.lock! if plan.persisted?
        previous = local_price_snapshot(plan)
        plan.assign_attributes(plan_attrs)
        plan.stripe_product_id = LOCAL_PRODUCT_ID
        plan.stripe_price_id = price_id
        plan.save!

        current = BillingPlanPrice.find_or_initialize_by(stripe_price_id: price_id)
        current.assign_attributes(
          billing_plan: plan,
          amount_cents: plan.amount_cents,
          currency: plan.currency,
          interval: plan.interval,
          interval_count: plan.interval_count,
          active: true,
          current: true,
          retired_at: nil,
          metadata: { "billing_plan_key" => plan.key }
        )

        plan.billing_plan_prices.current.where.not(id: current.id).lock.each do |history|
          history.update!(current: false, retired_at: history.retired_at || now)
        end
        preserve_local_price_snapshot!(plan:, snapshot: previous, current_price_id: price_id, retired_at: now)
        current.save!
        plan
      end
    end

    def seed_entitlements!(profile: Seeds::Profiles.current)
      return unless defined?(BillingPlanEntitlement)

      pandora = ExpertAdvisor.unscoped.find_by(ea_id: "pandora_box")
      return unless pandora

      BillingPlan.where(key: Billing::PandoraPricing::PLAN_KEYS).find_each do |plan|
        BillingPlanEntitlement.find_or_create_by!(billing_plan: plan, expert_advisor: pandora)
      end
    end

    def local_price_snapshot(plan)
      return unless plan.persisted? && plan.stripe_price_id.present?

      {
        stripe_price_id: plan.stripe_price_id,
        amount_cents: plan.amount_cents,
        currency: plan.currency,
        interval: plan.interval,
        interval_count: plan.interval_count
      }
    end

    def preserve_local_price_snapshot!(plan:, snapshot:, current_price_id:, retired_at:)
      return if snapshot.blank? || snapshot[:stripe_price_id] == current_price_id

      history = BillingPlanPrice.find_or_initialize_by(stripe_price_id: snapshot.fetch(:stripe_price_id))
      history.assign_attributes(
        billing_plan: plan,
        amount_cents: snapshot.fetch(:amount_cents),
        currency: snapshot.fetch(:currency),
        interval: snapshot[:interval],
        interval_count: snapshot[:interval_count],
        active: true,
        current: false,
        retired_at: history.retired_at || retired_at,
        metadata: { "billing_plan_key" => plan.key }
      )
      history.save!
    end

    def stripe_seeding_enabled?
      return true if ENV["STRIPE_PRIVATE_KEY"].present?
      return false if Rails.env.test?

      raise ArgumentError, "STRIPE_PRIVATE_KEY is required to seed billing plans outside test."
    end
  end

  module Subscriptions
    module_function

    def seed_manual_subscription_for(user:, recorded_by: nil, tier: Billing::PandoraPricing::TIER, interval_key: "monthly")
      return unless user
      return unless defined?(ManualSubscription) && defined?(BillingPlan)
      return if ManualSubscription.active.where(user: user).exists?

      plan_key = "#{tier}_#{interval_key}"
      plan = BillingPlan.subscription.active.find_by(key: plan_key) || BillingPlan.subscription.active.order(:amount_cents).first
      return unless plan

      admin = recorded_by || user
      now = Time.current
      subscription = ManualSubscription.find_or_initialize_by(user: user, billing_plan: plan)
      subscription.assign_attributes(
        amount_cents: plan.amount_cents,
        granted_days: 30,
        payment_status: ManualSubscription::PAYMENT_STATUSES[:paid],
        currency: plan.currency,
        paid_at: now - 15.days,
        starts_at: now - 15.days,
        ends_at: now + 15.days,
        status: ManualSubscription::STATUSES[:active],
        recorded_by_admin: admin
      )
      subscription.save!
    end
  end

  module DashboardMain
    module_function

    QA_BROKERS = ["Apex FX", "Fusion Markets", "Demo Lab", "BlueRock Markets", "Quantum Trades"].freeze
    QA_ACCOUNT_TYPES = %i[real demo real].freeze
    QA_DAYS = 60

    def seed_for(user:, core_records:, qa_records:)
      return unless user

      encoder = Licenses::LicenseKeyEncoder.new
      unless encoder.configured?
        Rails.logger.warn("Skipping QA license seeding because EA license keys are not configured.")
        return
      end

      seed_licenses(user: user, core_records: core_records, qa_records: qa_records, encoder: encoder)
      seed_broker_accounts(user: user)
    end

    def seed_licenses(user:, core_records:, qa_records:, encoder:)
      now = Time.current

      Array(core_records).each do |record|
        upsert_license(
          user: user,
          expert_advisor: record,
          status: "active",
          plan_interval: "monthly",
          expires_at: now + 30.days,
          encoder: encoder
        )
      end

      qa_map = Array(qa_records).index_by(&:ea_id)

      upsert_license(
        user: user,
        expert_advisor: qa_map["qa_trial_ea"],
        status: "active",
        plan_interval: "monthly",
        expires_at: now + 30.days,
        encoder: encoder
      )

      upsert_license(
        user: user,
        expert_advisor: qa_map["qa_active_ea"],
        status: "active",
        plan_interval: "monthly",
        expires_at: now + 30.days,
        encoder: encoder
      )

      upsert_license(
        user: user,
        expert_advisor: qa_map["qa_expired_ea"],
        status: "expired",
        plan_interval: "monthly",
        expires_at: now - 2.days,
        encoder: encoder
      )

      upsert_license(
        user: user,
        expert_advisor: qa_map["qa_revoked_ea"],
        status: "revoked",
        plan_interval: "monthly",
        expires_at: now - 1.day,
        encoder: encoder
      )
    end

    def seed_broker_accounts(user:)
      return unless defined?(BrokerAccountDailyResult)
      return unless defined?(BrokerAccount)

      License.includes(:expert_advisor).where(user: user).order(:id).each_with_index do |license, license_idx|
        3.times do |account_idx|
          broker_name = QA_BROKERS[(license_idx + account_idx) % QA_BROKERS.size]
          account_type = QA_ACCOUNT_TYPES[account_idx % QA_ACCOUNT_TYPES.size]
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
          seed_daily_results(broker_account, days: QA_DAYS, seed: broker_account.account_number)
        end
      end
    end

    def upsert_license(user:, expert_advisor:, status:, encoder:, expires_at: nil, trial_ends_at: nil, plan_interval: nil)
      return unless expert_advisor

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

    def lane_seed_context_for(broker_account)
      return nil unless broker_account

      license = broker_account.license
      expert_advisor = license&.expert_advisor
      source = license&.source.to_s.presence || "seed"
      email = license&.user&.email.to_s

      if license.blank? || expert_advisor.blank? || email.blank?
        Rails.logger.warn(
          "[Seeds::DashboardMain] missing lane context broker_account_id=#{broker_account.id} " \
          "license_id=#{license&.id} expert_advisor_id=#{expert_advisor&.id}"
        )
        return nil
      end

      allocation = Licenses::LaneMagicNumberAllocator.new(
        license: license,
        source: source,
        email: email,
        broker_account: {
          company: broker_account.company,
          account_number: broker_account.account_number,
          account_type: broker_account.account_type
        }
      ).call

      unless allocation.ok? && allocation.magic_number.to_i.positive?
        Rails.logger.warn(
          "[Seeds::DashboardMain] lane magic allocation failed broker_account_id=#{broker_account.id} " \
          "license_id=#{license.id} error=#{allocation.error.inspect} code=#{allocation.code.inspect}"
        )
        return nil
      end

      { expert_advisor: expert_advisor, magic_number: allocation.magic_number.to_i }
    end

    def daily_result_exists?(broker_account, date, expert_advisor_id:, magic_number:)
      BrokerAccountDailyResult
        .where(
          broker_account_id: broker_account.id,
          expert_advisor_id: expert_advisor_id,
          magic_number: magic_number
        )
        .where("((to_timestamp(result_timestamp) AT TIME ZONE 'UTC')::date) = ?", date)
        .exists?
    end

    def seed_daily_results(broker_account, days:, seed:)
      lane_context = lane_seed_context_for(broker_account)
      return unless lane_context

      rng = Random.new(seed)
      end_date = Time.current.utc.to_date
      start_date = end_date - (days - 1)

      (0...days).each do |offset|
        date = start_date + offset
        next if ((broker_account.account_number + offset) % 13).zero?
        next if daily_result_exists?(
          broker_account,
          date,
          expert_advisor_id: lane_context[:expert_advisor].id,
          magic_number: lane_context[:magic_number]
        )

        timestamp = Time.utc(date.year, date.month, date.day, 12, 0, 0).to_i
        volatility = broker_account.account_type == "real" ? 40.0 : 25.0
        trend = (offset - (days / 2.0)) * (broker_account.account_type == "real" ? 0.4 : 0.2)
        value = (rng.rand(-volatility..volatility) + trend).round(2)

        BrokerAccountDailyResult.create!(
          broker_account: broker_account,
          expert_advisor: lane_context[:expert_advisor],
          magic_number: lane_context[:magic_number],
          result_timestamp: timestamp,
          result_value: value
        )
      end
    end
  end

  module DashboardSamples
    module_function

    RANGE_DAYS = 30
    SAMPLE_HOUR = 10

    def seed_activity_for(user:)
      return unless user

      scatter_scope(user.licenses, offset_step: 3)
      scatter_scope(user.course_enrollments, offset_step: 5)
      scatter_broker_accounts(user)
      scatter_course_progress(user)
    end

    def scatter_scope(scope, offset_step:)
      base = Time.current.utc.to_date
      scope.find_each.with_index do |record, idx|
        offset = (idx * offset_step) % RANGE_DAYS
        time = sample_time(base - offset.days)
        record.update_columns(created_at: time, updated_at: time)
      end
    end

    def scatter_broker_accounts(user)
      return unless defined?(BrokerAccount)

      scope = BrokerAccount.joins(license: :user).where(licenses: { user_id: user.id })
      scatter_scope(scope, offset_step: 4)
    end

    def scatter_course_progress(user)
      return unless defined?(CourseLessonProgress)

      base = Time.current.utc.to_date
      user.course_lesson_progresses.where(status: "completed").find_each.with_index do |progress, idx|
        offset = (idx * 2) % RANGE_DAYS
        time = sample_time(base - offset.days)
        progress.update_columns(created_at: time, updated_at: time, completed_at: time)
      end
    end

    def sample_time(date)
      Time.utc(date.year, date.month, date.day, SAMPLE_HOUR, 0, 0)
    end
  end

  module DashboardAnalytics
    module_function

    RANGE_DAYS = 30
    RECENT_HOURS = 24
    REPORT_LIMIT = 8

    def seed_for(user:)
      return unless user

      seed_recent_results(user: user)
      seed_course_enrollments(user: user)
      seed_lesson_progress(user: user)
      seed_license_expirations(user: user)
    end

    def seed_recent_results(user:)
      return unless defined?(BrokerAccountDailyResult)
      return unless defined?(BrokerAccount)

      accounts = BrokerAccount.joins(license: :user).where(licenses: { user_id: user.id }).distinct.to_a
      return if accounts.empty?

      accounts.each do |account|
        Seeds::DashboardMain.seed_daily_results(account, days: RANGE_DAYS, seed: account.account_number)
      end

      cutoff = RECENT_HOURS.hours.ago.to_i
      accounts.each_with_index do |account, idx|
        lane_context = Seeds::DashboardMain.lane_seed_context_for(account)
        next unless lane_context
        next if BrokerAccountDailyResult
                  .where(
                    broker_account: account,
                    expert_advisor_id: lane_context[:expert_advisor].id,
                    magic_number: lane_context[:magic_number]
                  )
                  .where("result_timestamp >= ?", cutoff)
                  .exists?

        timestamp = Time.current.utc.to_i - (idx * 3600)
        value = recent_result_value(account_number: account.account_number, offset: idx)
        BrokerAccountDailyResult.create!(
          broker_account: account,
          expert_advisor: lane_context[:expert_advisor],
          magic_number: lane_context[:magic_number],
          result_timestamp: timestamp,
          result_value: value
        )
      end
    end

    def seed_course_enrollments(user:)
      return unless defined?(CourseEnrollment)
      return unless defined?(Course)

      courses = Course.order(:position)
      return if courses.empty?

      now = Time.current
      progress_values = [0, 18, 42, 67, 85, 100]

      courses.each_with_index do |course, idx|
        progress = progress_values[idx % progress_values.length]
        enrollment = CourseEnrollment.find_or_initialize_by(user: user, course: course)
        enrollment.progress_percent = progress
        enrollment.started_at ||= progress.zero? ? nil : (now - (idx + 2).days)
        enrollment.completed_at = progress >= 100 ? (now - (idx + 1).days) : nil
        enrollment.last_lesson ||= course.course_lessons.order(:position).last
        enrollment.save!
      end
    end

    def seed_lesson_progress(user:)
      return unless defined?(CourseLessonProgress)
      return unless defined?(CourseLesson)

      lessons = CourseLesson.joins(course_module: :course)
                            .order("courses.position ASC, course_modules.position ASC, course_lessons.position ASC")
                            .limit(REPORT_LIMIT)
      return if lessons.empty?

      now = Time.current
      progress_points = [15, 35, 55, 75, 90, 45, 65, 80]

      lessons.each_with_index do |lesson, idx|
        percent = progress_points[idx % progress_points.length]
        duration = lesson.duration_seconds.to_i
        duration = 600 if duration <= 0
        progress_seconds = ((duration * percent) / 100.0).round
        progress_seconds = [progress_seconds, duration].min

        progress = CourseLessonProgress.find_or_initialize_by(user: user, course_lesson: lesson)
        progress.progress_seconds = progress_seconds
        progress.last_watched_at = now - idx.days
        progress.status = percent >= 80 ? "completed" : "started"
        progress.completed_at = percent >= 80 ? now - idx.days : nil
        progress.save!

        enrollment = CourseEnrollment.find_or_initialize_by(user: user, course: lesson.course)
        enrollment.last_lesson = lesson
        enrollment.started_at ||= progress.last_watched_at
        enrollment.save!
      end
    end

    def seed_license_expirations(user:)
      return unless defined?(License)

      now = Time.current
      offsets = [3, 7, 10, 14, 21, 30, 45, 60]

      user.licenses.active_or_trial.order(:id).each_with_index do |license, idx|
        expires_at = now + offsets[idx % offsets.length].days
        if license.trial?
          license.update!(trial_ends_at: expires_at)
        else
          license.update!(expires_at: expires_at)
        end
      end
    end

    def recent_result_value(account_number:, offset:)
      seed = account_number.to_i + (offset * 37)
      rng = Random.new(seed)
      rng.rand(-120.0..120.0).round(2)
    end
  end

  module MarketplaceAssets
    module_function

    def fixture_path
      Rails.root.join("db", "seeds", "fixtures", "marketplace_asset_sample.pdf")
    end

    def definitions
      [
        {
          slug: "quick_start_guide",
          sort_order: 1,
          status: "active",
          title_en: "Quick Start Guide",
          title_es: "Guia de inicio rapido",
          summary_en: "A fast onboarding guide to get you trading in minutes.",
          summary_es: "Guia rapida para comenzar a operar en minutos.",
          description_markdown_en: "# Quick Start\n\n- Platform setup\n- First trade checklist",
          description_markdown_es: "# Inicio rapido\n\n- Configuracion de la plataforma\n- Checklist de primera operacion",
          tags: %w[quick_start rules],
          file: fixture_path
        },
        {
          slug: "risk_checklist",
          sort_order: 2,
          status: "active",
          title_en: "Risk Checklist",
          title_es: "Checklist de riesgo",
          summary_en: "Daily rules to stay aligned with your risk plan.",
          summary_es: "Reglas diarias para seguir tu plan de riesgo.",
          description_markdown_en: "# Risk Checklist\n\n- Max drawdown rules\n- Session limits",
          description_markdown_es: "# Checklist de riesgo\n\n- Reglas de drawdown maximo\n- Limites de sesion",
          tags: %w[risk checklist],
          file: fixture_path
        },
        {
          slug: "session_templates",
          sort_order: 3,
          status: "active",
          title_en: "Session Templates",
          title_es: "Plantillas de sesion",
          summary_en: "Printable templates for pre-trade and post-trade routines.",
          summary_es: "Plantillas imprimibles para rutinas pre y post trade.",
          description_markdown_en: "# Session Templates\n\n- Pre-trade flow\n- Post-trade review",
          description_markdown_es: "# Plantillas de sesion\n\n- Flujo pre trade\n- Revision post trade",
          tags: %w[templates routines],
          file: fixture_path
        }
      ]
    end

    def seed_assets!
      return unless defined?(MarketplaceAsset)

      definitions.each do |attrs|
        upsert_asset(attrs.dup)
      end
    end

    def upsert_asset(attrs)
      file_path = attrs.delete(:file)
      tags = attrs.delete(:tags)

      asset = MarketplaceAsset.find_or_initialize_by(slug: attrs[:slug])
      asset.assign_attributes(attrs)
      asset.tag_list = Array(tags).map(&:to_s) if tags
      asset.save!

      attach_file(asset, file_path)
      asset
    end

    def attach_file(asset, file_path)
      return unless file_path&.exist?
      return if asset.file.attached?

      File.open(file_path) do |file|
        asset.file.attach(
          io: file,
          filename: File.basename(file_path),
          content_type: "application/pdf"
        )
      end
    end
  end

  module MarketplaceProducts
    module_function

    def definitions(profile: Seeds::Profiles.current)
      []
    end

    def prune_for_profile!(profile: Seeds::Profiles.current)
      return unless defined?(MarketplaceProduct)

      keep_slugs = definitions(profile: profile).map { |attrs| attrs[:slug] }
      scope = keep_slugs.empty? ? MarketplaceProduct.all : MarketplaceProduct.where.not(slug: keep_slugs)
      scope.includes(:billing_plan).find_each do |product|
        product.update!(status: "draft") if product.active?
        product.billing_plan&.update!(active: false) if product.billing_plan&.active?
      end
    end

    def prod_mirror_definitions
      [
        {
          slug: "ea_pandora_box",
          sort_order: 1,
          title_en: "Pandora Box",
          title_es: "Pandora Box",
          summary_en: "Breakout EA for MT5 with directional modes and configurable risk controls.",
          summary_es: "EA de breakout para MT5 con modos de direccion y controles de riesgo configurables.",
          description_en: pandora_marketplace_markdown_en,
          description_es: pandora_marketplace_markdown_es,
          amount_cents: 59_900,
          image: Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_marketplace_img.jpg"),
          ea_ids: %w[pandora_box],
          course_slugs: [],
          asset_slugs: [],
          stripe_required: false
        }
      ]
    end

    def full_qa_definitions
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
          course_slugs: [],
          asset_slugs: %w[quick_start_guide session_templates]
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
          course_slugs: %w[trading-foundations beginner-momentum],
          asset_slugs: %w[risk_checklist]
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
          course_slugs: %w[intermediate-systems],
          asset_slugs: %w[session_templates risk_checklist]
        },
        {
          slug: "ea_sniper_panel",
          sort_order: 4,
          title_en: "Sniper Panel EA",
          title_es: "EA Panel Sniper",
          summary_en: "Risk-first panel EA with precision execution tools.",
          summary_es: "EA panel con enfoque en riesgo y ejecucion precisa.",
          description_en: "One-time access to the Sniper Advanced Panel EA with lifetime updates.",
          description_es: "Acceso unico al EA Sniper Advanced Panel con actualizaciones de por vida.",
          amount_cents: 5900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-03.jpg"),
          ea_ids: %w[sniper_advanced_panel],
          course_slugs: [],
          asset_slugs: [],
          stripe_required: false
        },
        {
          slug: "ea_momentum_pulse",
          sort_order: 5,
          title_en: "Momentum Pulse Indicator",
          title_es: "Indicador Momentum Pulse",
          summary_en: "Visual momentum indicator for clean entry signals.",
          summary_es: "Indicador visual de momentum para entradas claras.",
          description_en: "One-time access to the Momentum Pulse Indicator with lifetime updates.",
          description_es: "Acceso unico al Indicador Momentum Pulse con actualizaciones de por vida.",
          amount_cents: 3900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-04.jpg"),
          ea_ids: %w[momentum_pulse_indicator],
          course_slugs: [],
          asset_slugs: [],
          stripe_required: false
        },
        {
          slug: "course_trading_foundations",
          sort_order: 6,
          title_en: "Trading Foundations Course",
          title_es: "Curso Fundamentos de Trading",
          summary_en: "Start with the core platform and risk workflow.",
          summary_es: "Comienza con la plataforma y flujo de riesgo.",
          description_en: "One-time access to the Trading Foundations course.",
          description_es: "Acceso unico al curso Fundamentos de Trading.",
          amount_cents: 4900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-05.jpg"),
          ea_ids: [],
          course_slugs: %w[trading-foundations],
          asset_slugs: [],
          stripe_required: false
        },
        {
          slug: "course_intermediate_systems",
          sort_order: 7,
          title_en: "Intermediate Systems Course",
          title_es: "Curso Sistemas Intermedios",
          summary_en: "Advanced structure and system design frameworks.",
          summary_es: "Estructura avanzada y diseno de sistemas.",
          description_en: "One-time access to the Intermediate Systems course.",
          description_es: "Acceso unico al curso Sistemas Intermedios.",
          amount_cents: 6900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-07.jpg"),
          ea_ids: [],
          course_slugs: %w[intermediate-systems],
          asset_slugs: [],
          stripe_required: false
        },
        {
          slug: "course_orderflow_lab",
          sort_order: 8,
          title_en: "Orderflow Lab Course",
          title_es: "Curso Laboratorio de orderflow",
          summary_en: "Deep dive into liquidity mapping and flow validation.",
          summary_es: "Inmersion en mapa de liquidez y validacion de flujo.",
          description_en: "One-time access to the Orderflow Lab course.",
          description_es: "Acceso unico al curso Laboratorio de orderflow.",
          amount_cents: 7200,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-30.jpg"),
          ea_ids: [],
          course_slugs: %w[orderflow-lab],
          asset_slugs: [],
          stripe_required: false
        },
        {
          slug: "asset_quick_start_guide",
          sort_order: 9,
          title_en: "Quick Start Guide",
          title_es: "Guia de Inicio Rapido",
          summary_en: "A fast onboarding guide to get you trading in minutes.",
          summary_es: "Guia rapida para comenzar a operar en minutos.",
          description_en: "One-time access to the Quick Start Guide asset.",
          description_es: "Acceso unico al asset Guia de inicio rapido.",
          amount_cents: 1900,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-08.jpg"),
          ea_ids: [],
          course_slugs: [],
          asset_slugs: %w[quick_start_guide],
          stripe_required: false
        },
        {
          slug: "asset_risk_checklist",
          sort_order: 10,
          title_en: "Risk Checklist",
          title_es: "Checklist de Riesgo",
          summary_en: "Daily rules to stay aligned with your risk plan.",
          summary_es: "Reglas diarias para seguir tu plan de riesgo.",
          description_en: "One-time access to the Risk Checklist asset.",
          description_es: "Acceso unico al asset Checklist de riesgo.",
          amount_cents: 1700,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-10.jpg"),
          ea_ids: [],
          course_slugs: [],
          asset_slugs: %w[risk_checklist],
          stripe_required: false
        }
      ]
    end

    def seed_products!(profile: Seeds::Profiles.current)
      return unless defined?(MarketplaceProduct)
      return unless defined?(BillingPlan)

      desired_definitions = definitions(profile: profile)
      return if desired_definitions.empty?

      enforce_stripe_requirement!
      stripe_available = ENV["STRIPE_PRIVATE_KEY"].present?
      force_stripe = !Rails.env.test?
      stripe_manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: true)
      local_manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: false)

      desired_definitions.each do |attrs|
        attrs = attrs.dup
        stripe_required = force_stripe || attrs.delete(:stripe_required) { true }
        if stripe_required && !stripe_available
          if Rails.env.test?
            stripe_required = false
          else
            raise ArgumentError, "[Seeds::MarketplaceProducts] STRIPE_PRIVATE_KEY is required for slug=#{attrs[:slug]}"
          end
        end

        manager = stripe_required ? stripe_manager : local_manager
        upsert_product(manager, attrs, stripe_required: stripe_required)
      end
    end

    def upsert_product(manager, attrs, stripe_required:)
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
        plan_attributes: plan_attributes(attrs, stripe_required: stripe_required)
      )

      attach_image(product, attrs[:image])
      attach_entitlements(product.billing_plan, attrs[:ea_ids], attrs[:course_slugs], attrs[:asset_slugs])
    end

    def plan_attributes(attrs, stripe_required:)
      plan_attrs = {
        amount_cents: attrs[:amount_cents],
        currency: BillingPlans::DEFAULT_CURRENCY
      }
      return plan_attrs if stripe_required

      stripe_product_id, stripe_price_id = seed_stripe_ids(attrs[:slug])
      plan_attrs[:stripe_product_id] = attrs[:stripe_product_id] || stripe_product_id
      plan_attrs[:stripe_price_id] = attrs[:stripe_price_id] || stripe_price_id
      plan_attrs
    end

    def enforce_stripe_requirement!
      return if ENV["STRIPE_PRIVATE_KEY"].present?
      return if Rails.env.test?

      raise ArgumentError, "STRIPE_PRIVATE_KEY is required to seed marketplace products outside test."
    end

    def pandora_marketplace_markdown_en
      <<~MARKDOWN.strip
        # Pandora Box EA

        Pandora Box EA is an Expert Advisor for MetaTrader 5 focused on breakout execution with configurable direction modes and risk controls.

        ## Detailed behavior

        Pandora Box builds a price box over a selected session window and monitors breakouts above and below that range. When a breakout happens, the EA executes in one direction according to its configuration and stops once the configured profit behavior is reached.

        ## Key capabilities

        - Full automation for breakout execution.
        - Configurable setup for range window, stop loss, and take profit.
        - Direction controls and operation flow tuning.
      MARKDOWN
    end

    def pandora_marketplace_markdown_es
      path = Rails.root.join("docs_eas", "pandora_box_ea", "pandora_box_ea_marketplace.md")
      markdown = path.exist? ? File.read(path) : ""
      cleaned = strip_markdown_images(markdown)
      return cleaned if cleaned.present?

      <<~MARKDOWN.strip
        # Pandora Box EA

        Pandora Box EA es un Asesor Experto para MetaTrader 5 enfocado en breakouts con configuracion flexible de direccion y riesgo.
      MARKDOWN
    end

    def strip_markdown_images(markdown)
      cleaned = markdown.to_s.gsub(/!\[[^\]]*\]\([^)]+\)/, "")
      cleaned.gsub(/\n{3,}/, "\n\n").strip
    end

    def seed_stripe_ids(slug)
      normalized = slug.to_s.parameterize(separator: "_")
      ["seed_prod_#{normalized}", "seed_price_#{normalized}"]
    end

    def attach_image(product, image_path)
      return unless image_path&.exist?
      return if product.image.attached?

      File.open(image_path) do |file|
        product.image.attach(
          io: file,
          filename: File.basename(image_path),
          content_type: image_content_type(image_path)
        )
      end
    end

    def image_content_type(image_path)
      case File.extname(image_path.to_s).downcase
      when ".png"
        "image/png"
      when ".webp"
        "image/webp"
      when ".svg"
        "image/svg+xml"
      when ".jpg", ".jpeg"
        "image/jpeg"
      else
        "application/octet-stream"
      end
    end

    def attach_entitlements(plan, ea_ids, course_slugs, asset_slugs)
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

      Array(asset_slugs).each do |slug|
        asset = MarketplaceAsset.find_by(slug: slug)
        next unless asset

        AssetPlanEntitlement.find_or_create_by!(
          billing_plan: plan,
          marketplace_asset: asset
        )
      end
    end
  end

  module Addons
    module_function

    FIBONACCI_ADDONABLE_KEY = "fibonacci_elite".freeze

    def definitions(profile: Seeds::Profiles.current)
      []
    end

    def legacy_full_qa_definitions
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
        },
        {
          key: "session_templates_pack",
          slug: "addon_session_templates_pack",
          sort_order: 13,
          title_en: "Session Templates Pack",
          title_es: "Pack Plantillas de Sesion",
          summary_en: "Bonus layouts for the Session Templates asset.",
          summary_es: "Plantillas extra para el asset Session Templates.",
          description_en: "A paid add-on with extra printable templates and checklists.",
          description_es: "Add-on de pago con plantillas y checklists adicionales.",
          amount_cents: 1500,
          image: Rails.root.join("app", "assets", "templates", "mosaic", "images", "applications-image-13.jpg"),
          addonable_type: "MarketplaceAsset",
          addonable_key: "session_templates",
          stripe_required: false
        }
      ]
    end

    def fibonacci_definitions
      [
        fibonacci_addon(
          key: "addon_session_time_filter",
          slug: "addon_fibonacci_session_time_filter",
          sort_order: 20,
          title: "Time Filter Session Manager",
          amount_cents: 29_900,
          image_name: "Time Filter Session Manager.png",
          copy_slug: "addon-session-time-filter"
        ),
        fibonacci_addon(
          key: "addon_grid_strategy_config",
          slug: "addon_fibonacci_grid_strategy_config",
          sort_order: 21,
          title: "Grid Strategy Settings",
          amount_cents: 29_900,
          image_name: "Grid Strategy Settings.png",
          copy_slug: "addon-grid-strategy-settings"
        ),
        fibonacci_addon(
          key: "addon_candle_structure",
          slug: "addon_fibonacci_candle_structure_filter",
          sort_order: 22,
          title: "Candle Structure Filter",
          amount_cents: 29_900,
          image_name: "Candle Structure Filter.png",
          copy_slug: "addon-candle-structure-filter"
        ),
        fibonacci_addon(
          key: "addon_compound_trend_ride",
          slug: "addon_fibonacci_compound_trend_ride",
          sort_order: 23,
          title: "Compound Mode - Trend Ride",
          amount_cents: 29_900,
          image_name: "Compound Mode - Trend Ride.png",
          copy_slug: "addon-compound-trend-ride"
        ),
        fibonacci_addon(
          key: "addon_compound_pullback_continue",
          slug: "addon_fibonacci_compound_pullback_continue",
          sort_order: 24,
          title: "Compound Mode - Pullback Continue",
          amount_cents: 19_900,
          image_name: "Compound Mode - Pullback Continue.png",
          copy_slug: "addon-compound-pullback-continue"
        ),
        fibonacci_addon(
          key: "addon_compound_reversal_early",
          slug: "addon_fibonacci_compound_reversal_early",
          sort_order: 25,
          title: "Compound Mode - Reversal Early",
          amount_cents: 19_900,
          image_name: "Compound Mode - Reversal Early.png",
          copy_slug: "addon-compound-reversal-early"
        ),
        fibonacci_addon(
          key: "addon_compound_breakout_ready",
          slug: "addon_fibonacci_compound_breakout_ready",
          sort_order: 26,
          title: "Compound Mode - Breakout Ready",
          amount_cents: 29_900,
          image_name: "Compound Mode - Breakout Ready.png",
          copy_slug: "addon-compound-breakout-ready"
        ),
        fibonacci_addon(
          key: "addon_compound_volatility_trap",
          slug: "addon_fibonacci_compound_volatility_trap",
          sort_order: 27,
          title: "Compound Mode - Volatility Trap",
          amount_cents: 19_900,
          image_name: "Compound Mode - Volatility Trap.png",
          copy_slug: "addon-compound-volatility-trap"
        )
      ]
    end

    def fibonacci_addon(key:, slug:, sort_order:, title:, amount_cents:, image_name:, copy_slug:)
      description_en = fibonacci_markdown(locale: :en, copy_slug: copy_slug)
      description_es = fibonacci_markdown(locale: :es, copy_slug: copy_slug)

      {
        key: key,
        slug: slug,
        sort_order: sort_order,
        title_en: title,
        title_es: title,
        summary_en: summary_from_markdown(description_en, fallback: "#{title} add-on for Fibonacci Elite."),
        summary_es: summary_from_markdown(description_es, fallback: "Add-on #{title} para Fibonacci Elite."),
        description_en: description_en,
        description_es: description_es,
        amount_cents: amount_cents,
        image: Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_addons_images", image_name),
        addonable_type: "ExpertAdvisor",
        addonable_key: FIBONACCI_ADDONABLE_KEY
      }
    end

    def fibonacci_markdown(locale:, copy_slug:)
      path = Rails.root.join("docs_eas", "fibonacci_ea", "addons", "product_copy", locale.to_s, "#{copy_slug}.md")
      return "" unless path.exist?

      File.read(path)
    end

    def summary_from_markdown(markdown, fallback:)
      summary = markdown.to_s.each_line.map(&:strip).find do |line|
        next false if line.blank?
        next false if line.start_with?("#", "- ", "* ", "```")
        next false if line.match?(/\A\d+\.\s+/)
        next false if line.match?(/\A(description|descripcion)\z/i)

        true
      end.to_s

      if summary.start_with?("`") && summary.end_with?("`") && summary.length > 2
        summary = summary.delete_prefix("`").delete_suffix("`").strip
      end

      summary.presence || fallback
    end

    def seed_addons!(profile: Seeds::Profiles.current)
      return unless defined?(Addon)
      return unless defined?(MarketplaceProduct)
      return unless defined?(BillingPlan)

      desired_definitions = definitions(profile: profile)
      return if desired_definitions.empty?

      enforce_stripe_requirement!
      stripe_available = ENV["STRIPE_PRIVATE_KEY"].present?
      force_stripe = !Rails.env.test?
      stripe_manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: true)
      local_manager = Marketplace::ProductManager.new(logger: Rails.logger, stripe_required: false)

      desired_definitions.each do |attrs|
        attrs = attrs.dup
        stripe_required = force_stripe || attrs.delete(:stripe_required) { true }
        if stripe_required && !stripe_available
          if Rails.env.test?
            stripe_required = false
          else
            raise ArgumentError, "[Seeds::Addons] STRIPE_PRIVATE_KEY is required for addon=#{attrs[:key]}"
          end
        end

        addonable = resolve_addonable(attrs)
        next unless addonable

        manager = stripe_required ? stripe_manager : local_manager
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
          plan_attributes: addon_plan_attributes(attrs, stripe_required: stripe_required)
        )

        MarketplaceProducts.attach_image(product, attrs[:image])
        upsert_addon(attrs, product.billing_plan, addonable)
      end
    end

    def addon_plan_attributes(attrs, stripe_required:)
      plan_attrs = {
        amount_cents: attrs[:amount_cents],
        currency: BillingPlans::DEFAULT_CURRENCY
      }
      return plan_attrs if stripe_required

      stripe_product_id, stripe_price_id = MarketplaceProducts.seed_stripe_ids(attrs[:slug])
      plan_attrs[:stripe_product_id] = attrs[:stripe_product_id] || stripe_product_id
      plan_attrs[:stripe_price_id] = attrs[:stripe_price_id] || stripe_price_id
      plan_attrs
    end

    def enforce_stripe_requirement!
      return if ENV["STRIPE_PRIVATE_KEY"].present?
      return if Rails.env.test?

      raise ArgumentError, "STRIPE_PRIVATE_KEY is required to seed add-ons outside test."
    end

    def resolve_addonable(attrs)
      case attrs[:addonable_type]
      when "ExpertAdvisor"
        ExpertAdvisor.find_by(ea_id: attrs[:addonable_key])
      when "Course"
        Course.find_by(slug: attrs[:addonable_key])
      when "MarketplaceAsset"
        MarketplaceAsset.find_by(slug: attrs[:addonable_key])
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

  module MarketplacePurchases
    module_function

    SEED_USERS = [
      { email: "marketplace.seed.1@example.com", name: "Marketplace Seed 1" },
      { email: "marketplace.seed.2@example.com", name: "Marketplace Seed 2" },
      { email: "marketplace.seed.3@example.com", name: "Marketplace Seed 3" },
      { email: "marketplace.seed.4@example.com", name: "Marketplace Seed 4" },
      { email: "marketplace.seed.5@example.com", name: "Marketplace Seed 5" }
    ].freeze

    def seed_for(qa_user:)
      return unless defined?(MarketplacePurchase)

      users = seed_users
      seed_purchase_matrix(users) if users.any?
      seed_qa_purchases(qa_user) if qa_user
    end

    def seed_users
      return [] unless defined?(User)

      SEED_USERS.map do |attrs|
        Seeds::QaUsers.upsert_user(
          email: attrs[:email],
          name: attrs[:name],
          role: :trader,
          password: QaUsers::DEFAULT_PASSWORD
        )
      end.compact
    end

    def seed_purchase_matrix(users)
      seed_purchases(slug: "ea_sniper_panel", users: users, offsets: [3, 6, 10, 14, 19])
      seed_purchases(slug: "course_trading_foundations", users: users.take(3), offsets: [4, 9, 21])
      seed_purchases(slug: "addon_sniper_news_filter", users: users.take(2), offsets: [5, 12])
      seed_purchases(slug: "asset_quick_start_guide", users: users.take(3), offsets: [45, 53, 60])
      seed_purchases(slug: "asset_risk_checklist", users: users.last(2), offsets: [65, 72])
      seed_purchases(slug: "ea_starter_bundle", users: users.drop(1).take(3), offsets: [41, 55, 68])
      seed_purchases(slug: "course_essentials", users: users.last(1), offsets: [80])
      seed_purchases(slug: "addon_pandora_risk_guard", users: users.drop(2).take(1), offsets: [38])
      seed_purchases(slug: "addon_session_templates_pack", users: users.last(2), offsets: [52, 63])
      seed_purchases(slug: "addon_foundations_workbook", users: users.take(1), offsets: [85])
    end

    def seed_qa_purchases(qa_user)
      seed_purchase(slug: "pro_trader_bundle", user: qa_user, offset: 12)
      seed_purchase(slug: "addon_foundations_workbook", user: qa_user, offset: 8)
    end

    def seed_purchases(slug:, users:, offsets:)
      offsets.each_with_index do |offset, idx|
        user = users[idx]
        next unless user

        seed_purchase(slug: slug, user: user, offset: offset)
      end
    end

    def seed_purchase(slug:, user:, offset:)
      product = MarketplaceProduct.find_by(slug: slug)
      return unless product

      plan = product.billing_plan
      return unless plan&.one_time?

      purchase = MarketplacePurchase.find_or_initialize_by(user: user, billing_plan: plan)
      purchase.purchased_at = Time.current - offset.days
      purchase.save!
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
      source_checksum = bundle_checksum(bundle_path)

      if bundle.bundle_file.attached?
        blob = bundle.bundle_file.blob
        if blob.checksum == source_checksum
          blob.update!(filename: filename) if blob.filename.to_s != filename
          return
        end

        Rails.logger.info("[Seeds::ExpertAdvisorBundles] replacing bundle for expert_advisor_id=#{bundle.expert_advisor_id}, bundle_key=#{bundle.bundle_key} (checksum changed)")
        bundle.bundle_file.purge
      end

      File.open(bundle_path) do |file|
        bundle.bundle_file.attach(
          io: file,
          filename: filename,
          content_type: "application/x-rar-compressed"
        )
      end
    end

    def bundle_checksum(bundle_path)
      Base64.strict_encode64(Digest::MD5.file(bundle_path).digest)
    end

    def addon_combinations(addon_keys)
      keys = addon_keys.sort
      (1..keys.size).flat_map { |size| keys.combination(size).to_a }
    end
  end

  module FibonacciQaAccess
    module_function

    BASE_ONLY_EMAIL = "qa.fibonacci.base@example.com".freeze
    PARTIAL_OWNED_EMAIL = "qa.fibonacci.partial@example.com".freeze
    PARTIAL_OWNED_ADDON_KEYS = %w[
      addon_session_time_filter
      addon_compound_pullback_continue
    ].freeze

    def seed!
      return {} unless defined?(User)
      return {} unless defined?(License)
      return {} unless defined?(MarketplacePurchase)

      expert_advisor = ExpertAdvisor.find_by(ea_id: "fibonacci_elite")
      return {} unless expert_advisor

      encoder = Licenses::LicenseKeyEncoder.new
      unless encoder.configured?
        Rails.logger.warn("[Seeds::FibonacciQaAccess] skipped: EA license keys are not configured.")
        return {}
      end

      base_only_user = QaUsers.upsert_user(
        email: BASE_ONLY_EMAIL,
        name: "QA Fibonacci Base",
        role: :trader,
        password: QaUsers::DEFAULT_PASSWORD
      )
      partial_owned_user = QaUsers.upsert_user(
        email: PARTIAL_OWNED_EMAIL,
        name: "QA Fibonacci Partial",
        role: :trader,
        password: QaUsers::DEFAULT_PASSWORD
      )

      upsert_fibonacci_license(user: base_only_user, expert_advisor: expert_advisor, encoder: encoder)
      upsert_fibonacci_license(user: partial_owned_user, expert_advisor: expert_advisor, encoder: encoder)

      remove_fibonacci_addon_purchases(user: base_only_user, expert_advisor: expert_advisor)
      seed_partial_fibonacci_addons(user: partial_owned_user, expert_advisor: expert_advisor)

      {
        base_only: base_only_user,
        partial_owned: partial_owned_user
      }
    end

    def upsert_fibonacci_license(user:, expert_advisor:, encoder:)
      expires_at = Time.current + 60.days
      license = License.find_or_initialize_by(user: user, expert_advisor: expert_advisor)
      license.status = "active"
      license.plan_interval = "monthly"
      license.trial_ends_at = nil
      license.expires_at = expires_at
      license.source = "seed"
      license.last_synced_at = Time.current
      license.encrypted_key = encoder.generate(
        email: user.email,
        ea_id: expert_advisor.ea_id,
        expires_at: expires_at
      )
      license.save!
      license
    end

    def seed_partial_fibonacci_addons(user:, expert_advisor:)
      addon_scope = Addon.where(addonable: expert_advisor)
      plan_ids = addon_scope.pluck(:billing_plan_id).compact.uniq
      return if plan_ids.empty?

      desired_plan_ids = addon_scope.where(key: PARTIAL_OWNED_ADDON_KEYS).pluck(:billing_plan_id).compact.uniq
      MarketplacePurchase.where(user: user, billing_plan_id: plan_ids - desired_plan_ids).delete_all

      desired_plan_ids.each_with_index do |plan_id, index|
        purchase = MarketplacePurchase.find_or_initialize_by(user: user, billing_plan_id: plan_id)
        purchase.purchased_at ||= Time.current - (index + 1).days
        purchase.save!
      end
    end

    def remove_fibonacci_addon_purchases(user:, expert_advisor:)
      plan_ids = Addon.where(addonable: expert_advisor).pluck(:billing_plan_id).compact.uniq
      return if plan_ids.empty?

      MarketplacePurchase.where(user: user, billing_plan_id: plan_ids).delete_all
    end
  end

  module QaUsers
    module_function

    DEFAULT_PASSWORD = "Password123!"
    DEFAULT_TRADER_EMAIL = "qa@example.com"
    DEFAULT_PARTNER_EMAIL = "qa.partner@example.com"
    DEFAULT_ELIGIBLE_PARTNER_EMAIL = "qa.partner.eligible@example.com"

    def seed!(
      trader_email: DEFAULT_TRADER_EMAIL,
      partner_email: DEFAULT_PARTNER_EMAIL,
      eligible_partner_email: DEFAULT_ELIGIBLE_PARTNER_EMAIL,
      password: DEFAULT_PASSWORD
    )
      return {} unless defined?(User)

      {
        trader: upsert_user(email: trader_email, name: "QA User", role: :trader, password: password),
        partner: upsert_user(email: partner_email, name: "QA Partner", role: :trader, password: password),
        eligible_partner: upsert_user(email: eligible_partner_email, name: "QA Eligible Partner", role: :trader, password: password)
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
    DEFAULT_ELIGIBLE_REFERRED_EMAILS = [
      "qa.eligible.referral1@example.com",
      "qa.eligible.referral2@example.com",
      "qa.eligible.referral3@example.com"
    ].freeze
    DEFAULT_PASSWORD = QaUsers::DEFAULT_PASSWORD
    DEFAULT_DISCOUNT_PERCENT = 15

    def seed_qa!(partner:, referred_emails: DEFAULT_REFERRED_EMAILS, password: DEFAULT_PASSWORD)
      return [] unless partner.present?
      return [] unless defined?(PartnerProfile) && defined?(PartnerMembership)
      return [] unless defined?(PartnerCommission) && defined?(PartnerPayoutRequest)
      return [] unless defined?(Refer)

      profile = PartnerProfile.find_or_create_by!(user: partner) do |partner_profile|
        partner_profile.discount_percent = DEFAULT_DISCOUNT_PERCENT
        partner_profile.commission_percent = DEFAULT_DISCOUNT_PERCENT
        partner_profile.payout_mode = :once_paid
        partner_profile.active = true
        partner_profile.started_at = Time.current
      end
      return [] unless profile

      if profile.discount_percent.nil? || profile.discount_percent.zero? || profile.commission_percent.nil? || profile.commission_percent.zero?
        profile.update!(discount_percent: DEFAULT_DISCOUNT_PERCENT, commission_percent: DEFAULT_DISCOUNT_PERCENT)
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

        attach_referral(profile, user)
        membership = upsert_membership(profile, user, depth: 1)
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

    def seed_eligible_qa!(partner:, referred_emails: DEFAULT_ELIGIBLE_REFERRED_EMAILS, password: DEFAULT_PASSWORD)
      return [] unless partner.present?
      return [] unless defined?(PartnerProfile) && defined?(PartnerMembership)
      return [] unless defined?(PartnerCommission) && defined?(PartnerPayoutRequest)
      return [] unless defined?(Refer)

      profile = upsert_partner_profile(partner)
      reset_click_ready_profile!(profile)

      referred_users = []

      referred_emails.each_with_index do |email, idx|
        user = QaUsers.upsert_user(
          email: email,
          name: "QA Eligible Referral #{idx + 1}",
          role: :trader,
          password: password
        )
        referred_users << user

        attach_referral(profile, user)
        membership = upsert_membership(profile, user, depth: 1)
        seed_eligible_commissions(
          profile: profile,
          membership: membership,
          user: user,
          index: idx
        )
      end

      seed_subscription_for(referred_users.first)

      referred_users
    end

    def attach_referral(profile, user)
      return unless user.respond_to?(:referrer)
      return if user.referrer == profile.user
      return if user.referrer.present? && user.referrer != profile.user

      Referrals::AttachReferrer.new(user: user, code: profile.referral_code).call
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
        percent_applied: profile.commission_percent_or_default,
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

    def seed_eligible_commissions(profile:, membership:, user:, index:)
      now = Time.current
      base_key = "seed:qa_partner_eligible_#{user.id || user.email}"
      amounts = [12_000, 8_500, 5_500]

      upsert_commission(
        profile: profile,
        membership: membership,
        user: user,
        seed_key: "#{base_key}:pending",
        status: :pending,
        commission_kind: index.zero? ? :initial : :renewal,
        amount_cents: amounts.fetch(index, 5_000),
        occurred_at: now - (index + 1).days
      )
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

    def upsert_partner_profile(partner)
      profile = PartnerProfile.find_or_create_by!(user: partner) do |partner_profile|
        partner_profile.discount_percent = DEFAULT_DISCOUNT_PERCENT
        partner_profile.commission_percent = DEFAULT_DISCOUNT_PERCENT
        partner_profile.payout_mode = :once_paid
        partner_profile.active = true
        partner_profile.started_at = Time.current
      end
      return profile if profile.discount_percent.present? && profile.commission_percent.present?

      profile.update!(discount_percent: DEFAULT_DISCOUNT_PERCENT, commission_percent: DEFAULT_DISCOUNT_PERCENT)
      profile
    end

    def reset_click_ready_profile!(profile)
      profile.partner_payout_requests.find_each do |request|
        request.partner_commissions.update_all(
          payout_request_id: nil,
          status: PartnerCommission.statuses[:pending],
          updated_at: Time.current
        )
      end

      profile.partner_payout_requests.delete_all
      profile.partner_commissions.update_all(
        payout_request_id: nil,
        status: PartnerCommission.statuses[:pending],
        updated_at: Time.current
      )
    end
  end
end
