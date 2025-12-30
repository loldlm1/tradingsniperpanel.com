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
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    headings = []

    doc.css("h1, h2, h3, h4").each do |node|
      level = node.name.delete_prefix("h").to_i
      id = node["id"].presence || node.text.parameterize
      node["id"] = id
      node["data-scrollspy-target"] = "" if with_toc
      node["class"] = merge_classes(node["class"], heading_classes(level))
      headings << Heading.new(id: id, text: node.text, level: level) if with_toc
    end

    doc.css("a").each do |node|
      node["class"] = merge_classes(node["class"], "text-blue-600 font-medium hover:underline")
    end

    doc.css("p").each do |node|
      node["class"] = merge_classes(node["class"], "leading-relaxed")
    end

    doc.css("ul").each do |node|
      node["class"] = merge_classes(node["class"], "list-disc list-inside space-y-2 pl-4")
    end

    doc.css("ol").each do |node|
      node["class"] = merge_classes(node["class"], "list-decimal list-inside space-y-2 pl-4")
    end

    doc.css("li").each do |node|
      node["class"] = merge_classes(node["class"], "leading-relaxed")
    end

    doc.css("pre").each do |node|
      node["class"] = merge_classes(node["class"], "relative rounded-sm bg-slate-900 text-slate-100 text-sm p-4 overflow-x-auto")
    end

    doc.css("code").each do |node|
      next if node.parent&.name == "pre"

      node["class"] = merge_classes(node["class"], "rounded-sm bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-100 px-1 py-0.5 text-xs")
    end

    doc.css("table").each do |node|
      node["class"] = merge_classes(node["class"], "w-full text-sm text-left border border-slate-200 dark:border-slate-700")
    end

    doc.css("thead").each do |node|
      node["class"] = merge_classes(node["class"], "bg-slate-50 dark:bg-slate-800")
    end

    doc.css("th").each do |node|
      node["class"] = merge_classes(node["class"], "px-3 py-2 font-semibold text-slate-700 dark:text-slate-200 border-b border-slate-200 dark:border-slate-700")
    end

    doc.css("td").each do |node|
      node["class"] = merge_classes(node["class"], "px-3 py-2 border-b border-slate-200 dark:border-slate-700 align-top")
    end

    if with_toc
      { html: safe(doc.to_html), headings: headings }
    else
      safe(doc.to_html)
    end
  end

  def self.safe(html)
    html.respond_to?(:html_safe) ? html.html_safe : html
  end
  private_class_method :safe

  def self.heading_classes(level)
    case level
    when 1
      "h2 text-slate-800 mb-4 dark:text-slate-200"
    else
      "h4 text-slate-800 scroll-mt-24 dark:text-slate-200"
    end
  end
  private_class_method :heading_classes

  def self.merge_classes(existing, extra)
    return extra if existing.blank?
    return existing if extra.blank?

    ([existing] + extra.to_s.split).join(" ")
  end
  private_class_method :merge_classes
end
