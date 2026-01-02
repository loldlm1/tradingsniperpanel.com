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
end
