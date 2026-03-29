require "digest"

module ProductReleases
  class SignatureBuilder
    def initialize(subject:, product_kind:)
      @subject = subject
      @product_kind = product_kind.to_s
    end

    def call
      case product_kind
      when "expert_advisor"
        expert_advisor_signature
      when "addon"
        "addon-available:v1"
      when "course"
        "course-published:v1"
      else
        raise ArgumentError, "Unsupported product kind: #{product_kind}"
      end
    end

    private

    attr_reader :subject, :product_kind

    def expert_advisor_signature
      parts = []
      parts << "ea_file:#{blob_checksum(subject.ea_files)}"
      bundle_parts = subject.expert_advisor_bundles
                          .select(&:active?)
                          .sort_by { |bundle| [bundle.sort_order.to_i, bundle.bundle_key.to_s] }
                          .map { |bundle| "#{bundle.bundle_key}:#{blob_checksum(bundle.bundle_file)}" }
      parts << "bundles:#{bundle_parts.join("|")}"

      Digest::SHA256.hexdigest(parts.join("--"))
    end

    def blob_checksum(attachment)
      attachment.attached? ? attachment.blob.checksum.to_s : "none"
    end
  end
end
