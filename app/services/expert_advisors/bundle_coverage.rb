module ExpertAdvisors
  class BundleCoverage
    Result = Struct.new(:required_keys, :available_keys, :missing_keys, keyword_init: true) do
      def complete?
        missing_keys.empty?
      end
    end

    def initialize(expert_advisor:, additional_addon_keys: [])
      @expert_advisor = expert_advisor
      @additional_addon_keys = Array(additional_addon_keys)
    end

    def call
      return Result.new(required_keys: [], available_keys: [], missing_keys: []) unless expert_advisor

      addon_keys = normalized_addon_keys
      required_keys = required_bundle_keys(addon_keys)
      available_keys = available_bundle_keys
      missing_keys = required_keys - available_keys

      Result.new(
        required_keys: required_keys,
        available_keys: available_keys,
        missing_keys: missing_keys
      )
    end

    private

    attr_reader :expert_advisor

    def normalized_addon_keys
      keys = expert_advisor.addons.pluck(:key) + additional_addon_keys
      keys.map(&:to_s).map(&:strip).reject(&:blank?).uniq.sort
    end

    def required_bundle_keys(addon_keys)
      return [] if addon_keys.empty?

      combos = (1..addon_keys.size).flat_map do |size|
        addon_keys.combination(size).map { |keys| keys.join("__") }
      end

      ["base"] + combos
    end

    def available_bundle_keys
      expert_advisor.expert_advisor_bundles.active
                    .includes(bundle_file_attachment: :blob)
                    .select { |bundle| bundle.bundle_file.attached? }
                    .map(&:bundle_key)
                    .uniq
    end

    attr_reader :additional_addon_keys
  end
end
