require "commonmarker"

class MarkdownRenderer
  def self.render(text)
    return "" if text.blank?

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
    html.respond_to?(:html_safe) ? html.html_safe : html
  end
end
