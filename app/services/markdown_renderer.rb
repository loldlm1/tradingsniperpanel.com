require "commonmarker"
require "nokogiri"

class MarkdownRenderer
  Heading = Struct.new(:id, :text, :level, keyword_init: true)

  def self.render(text, with_toc: false)
    return with_toc ? { html: "", headings: [] } : "" if text.blank?

    html = Commonmarker.to_html(
      text,
      options: {
        extension: {
          table: true,
          autolink: true,
          strikethrough: true
        }
      }
    )
    return safe(html) unless with_toc

    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    headings = []

    doc.css("h1, h2, h3, h4").each do |node|
      id = node["id"].presence || node.text.parameterize
      node["id"] = id
      headings << Heading.new(id: id, text: node.text, level: node.name.delete_prefix("h").to_i)
    end

    { html: safe(doc.to_html), headings: headings }
  end

  def self.safe(html)
    html.respond_to?(:html_safe) ? html.html_safe : html
  end
  private_class_method :safe
end
