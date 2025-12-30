require "commonmarker"
require "nokogiri"

module ExpertAdvisors
  class GuidePreview
    Preview = Struct.new(:heading, :paragraph, keyword_init: true)

    def self.for_entries(entries, locale: I18n.locale)
      entries.each_with_object({}) do |entry, previews|
        previews[entry.expert_advisor.id] = call(entry.expert_advisor.doc_guide_for(locale))
      end
    end

    def self.call(markdown)
      return Preview.new(heading: nil, paragraph: nil) if markdown.blank?

      html = Commonmarker.to_html(
        markdown,
        options: {
          extension: {
            table: true,
            autolink: true,
            strikethrough: true
          }
        }
      )
      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      heading = fragment.at_css("h1, h2, h3, h4")&.text&.strip
      paragraph = fragment.at_css("p")&.text&.strip
      paragraph ||= fragment.at_css("li")&.text&.strip

      Preview.new(heading: heading, paragraph: paragraph)
    end
  end
end
