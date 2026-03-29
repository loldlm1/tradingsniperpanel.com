module ProductReleases
  class Publish
    Result = Struct.new(:release, :changed_items, keyword_init: true) do
      def published?
        release.present?
      end

      def item_count
        changed_items.size
      end
    end

    def initialize(published_by: nil, now: Time.current)
      @published_by = published_by
      @now = now
    end

    def call
      tracked_subjects = CatalogSnapshotBuilder.new.call
      snapshot_map = ProductReleaseSnapshot.all.index_by { |snapshot| snapshot_key(snapshot.subject_type, snapshot.subject_id, snapshot.product_kind) }
      changed_items = detect_changes(tracked_subjects, snapshot_map)

      release = nil
      ProductRelease.transaction do
        release = create_release!(changed_items) if changed_items.any?
        sync_snapshots!(tracked_subjects, snapshot_map)
      end

      Result.new(release: release, changed_items: changed_items)
    end

    private

    attr_reader :published_by, :now

    def detect_changes(tracked_subjects, snapshot_map)
      tracked_subjects.filter_map.with_index do |tracked_subject, index|
        snapshot = snapshot_map[tracked_subject.snapshot_key]
        action_type =
          case tracked_subject.product_kind
          when "expert_advisor"
            next unless snapshot.present?
            next if snapshot.signature == tracked_subject.signature

            "updated"
          when "addon", "course"
            next if snapshot.present?

            "added"
          else
            next
          end

        tracked_subject.to_h.merge(action_type: action_type, position: index)
      end
    end

    def create_release!(changed_items)
      release = ProductRelease.create!(
        published_by: published_by,
        published_at: now
      )

      changed_items.each do |item|
        release.product_release_items.create!(
          subject: item[:subject],
          product_kind: item[:product_kind],
          action_type: item[:action_type],
          title_en: item[:title_en],
          title_es: item[:title_es],
          position: item[:position]
        )
      end

      release
    end

    def sync_snapshots!(tracked_subjects, snapshot_map)
      tracked_subjects.each do |tracked_subject|
        snapshot = snapshot_map[tracked_subject.snapshot_key] || ProductReleaseSnapshot.new(
          subject_type: tracked_subject.subject_type,
          subject_id: tracked_subject.subject_id,
          product_kind: tracked_subject.product_kind
        )
        snapshot.signature = tracked_subject.signature
        snapshot.tracked_at = now
        snapshot.save! if snapshot.changed?
      end
    end

    def snapshot_key(subject_type, subject_id, product_kind)
      [subject_type, subject_id, product_kind]
    end
  end
end
