module Dashboard
  class SidebarRecentExpertAdvisors
    def initialize(entries:, limit: 5, active_ea_id: nil)
      @entries = Array(entries)
      @limit = limit
      @active_ea_id = active_ea_id.to_s.presence
    end

    def call
      recent = entries_with_sync.sort_by { |entry| entry.license&.last_synced_at.to_i }.reverse
      fallback = entries_without_sync.sort_by do |entry|
        [entry.expert_advisor.tier_rank.to_i, entry.expert_advisor.name.to_s.downcase]
      end
      list = (recent + fallback).uniq { |entry| entry.expert_advisor.id }.first(limit)

      append_active(list)
    end

    private

    attr_reader :entries, :limit, :active_ea_id

    def entries_with_sync
      entries.select { |entry| entry.license&.last_synced_at.present? }
    end

    def entries_without_sync
      entries.reject { |entry| entry.license&.last_synced_at.present? }
    end

    def append_active(list)
      return list unless active_ea_id

      active_entry = entries.find { |entry| entry.expert_advisor.ea_id.to_s == active_ea_id }
      return list unless active_entry
      return list if list.any? { |entry| entry.expert_advisor.id == active_entry.expert_advisor.id }

      list + [active_entry]
    end
  end
end
