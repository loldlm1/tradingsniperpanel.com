module ProductReleases
  class CatalogSnapshotBuilder
    TrackedSubject = Struct.new(
      :subject,
      :subject_type,
      :subject_id,
      :product_kind,
      :signature,
      :title_en,
      :title_es,
      keyword_init: true
    ) do
      def snapshot_key
        [subject_type, subject_id, product_kind]
      end
    end

    def call
      tracked_subjects = []
      tracked_subjects.concat(track_expert_advisors)
      tracked_subjects.concat(track_addon_products)
      tracked_subjects.concat(track_courses)
      tracked_subjects
    end

    private

    def track_expert_advisors
      ExpertAdvisor.active
                   .includes(
                     { ea_files_attachment: :blob },
                     expert_advisor_bundles: [{ bundle_file_attachment: :blob }]
                   )
                   .map do |expert_advisor|
        TrackedSubject.new(
          subject: expert_advisor,
          subject_type: "ExpertAdvisor",
          subject_id: expert_advisor.id,
          product_kind: "expert_advisor",
          signature: SignatureBuilder.new(subject: expert_advisor, product_kind: :expert_advisor).call,
          title_en: expert_advisor.name.to_s,
          title_es: expert_advisor.name.to_s
        )
      end
    end

    def track_addon_products
      MarketplaceProduct.active
                        .includes(billing_plan: :addon)
                        .select { |product| product.billing_plan&.addon.present? }
                        .map do |product|
        TrackedSubject.new(
          subject: product,
          subject_type: "MarketplaceProduct",
          subject_id: product.id,
          product_kind: "addon",
          signature: SignatureBuilder.new(subject: product, product_kind: :addon).call,
          title_en: product.title_en.to_s,
          title_es: product.title_es.to_s
        )
      end
    end

    def track_courses
      Course.published.map do |course|
        TrackedSubject.new(
          subject: course,
          subject_type: "Course",
          subject_id: course.id,
          product_kind: "course",
          signature: SignatureBuilder.new(subject: course, product_kind: :course).call,
          title_en: course.title_en.to_s,
          title_es: course.title_es.to_s
        )
      end
    end
  end
end
