require "commonmarker"
require "nokogiri"
require "erb"
require "rack/utils"
require "uri"

class MarkdownRenderer
  Heading = Struct.new(:id, :text, :level, keyword_init: true)
  VIDEO_TOKEN = /\[\[video:(.+?)\]\]/i
  YOUTUBE_TOKEN = /\[\[youtube:(.+?)\]\]/i

  def self.render(text, with_toc: false)
    return with_toc ? { html: "", headings: [] } : "" if text.blank?

    text, media_replacements = inject_media_tokens(text)
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
    replace_media_placeholders(doc, media_replacements)
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

  def self.inject_media_tokens(text)
    return [text, {}] if text.blank?

    replacements = {}
    counter = [0]
    updated = text.split(/```/).map.with_index do |segment, index|
      index.odd? ? segment : replace_media_tokens(segment, replacements, counter)
    end.join("```")

    [updated, replacements]
  end
  private_class_method :inject_media_tokens

  def self.replace_media_tokens(text, replacements, counter)
    text.gsub(VIDEO_TOKEN) do |match|
      html = video_embed_html(Regexp.last_match(1))
      next match unless html

      counter[0] += 1
      placeholder = "EA_VIDEO_EMBED_#{counter[0]}"
      replacements[placeholder] = html
      placeholder
    end.gsub(YOUTUBE_TOKEN) do |match|
      html = youtube_embed_html(Regexp.last_match(1))
      next match unless html

      counter[0] += 1
      placeholder = "EA_VIDEO_EMBED_#{counter[0]}"
      replacements[placeholder] = html
      placeholder
    end
  end
  private_class_method :replace_media_tokens

  def self.replace_media_placeholders(doc, replacements)
    return if replacements.blank?

    replacements.each do |placeholder, html|
      doc.xpath(".//text()[normalize-space()='#{placeholder}']").each do |text_node|
        fragment = Nokogiri::HTML::DocumentFragment.parse(html)
        if text_node.parent&.name == "p"
          text_node.parent.replace(fragment)
        else
          text_node.replace(fragment)
        end
      end
    end
  end
  private_class_method :replace_media_placeholders

  def self.video_embed_html(raw_source)
    source = raw_source.to_s.strip
    return nil if source.blank?

    url = resolve_asset_url(source)
    return nil if url.blank?

    mime_type = source.downcase.end_with?(".webm") ? "video/webm" : "video/mp4"
    title = ERB::Util.html_escape(I18n.t("dashboard.expert_advisors.guide_video_title"))
    safe_url = ERB::Util.html_escape(url)
    fallback = ERB::Util.html_escape(I18n.t("dashboard.expert_advisors.video_fallback"))

    <<~HTML.strip
      <div class="ea-guide-media my-2 flex justify-center" data-guide-embed="video">
        <div class="w-full max-w-2xl">
          <video class="w-full aspect-video rounded-sm bg-slate-900" autoplay muted controls loop playsinline aria-label="#{title}">
            <source src="#{safe_url}" type="#{mime_type}" />
            #{fallback}
          </video>
        </div>
      </div>
    HTML
  end
  private_class_method :video_embed_html

  def self.youtube_embed_html(raw_source)
    source = raw_source.to_s.strip
    return nil if source.blank?

    video_id = extract_youtube_id(source)
    return nil if video_id.blank?

    title = ERB::Util.html_escape(I18n.t("dashboard.expert_advisors.guide_video_title"))
    safe_id = ERB::Util.html_escape(video_id)
    src = "https://www.youtube.com/embed/#{safe_id}?autoplay=1&mute=1&playsinline=1&rel=0"

    <<~HTML.strip
      <div class="ea-guide-media my-2 flex justify-center" data-guide-embed="youtube">
        <div class="w-full max-w-2xl">
          <iframe class="w-full aspect-video rounded-sm bg-slate-900" src="#{src}" title="#{title}" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen loading="lazy"></iframe>
        </div>
      </div>
    HTML
  end
  private_class_method :youtube_embed_html

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

  def self.resolve_asset_url(source)
    return source if source.start_with?("//", "/")

    uri = URI.parse(source)
    if uri.scheme
      return source if %w[http https].include?(uri.scheme)
      return nil
    end

    ActionController::Base.helpers.asset_path(source)
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :resolve_asset_url

  def self.extract_youtube_id(source)
    return source if source.match?(/\A[\w-]{11}\z/)

    uri = URI.parse(source)
    return nil unless uri&.host

    host = uri.host.downcase
    if host.include?("youtu.be")
      uri.path.delete_prefix("/")
    elsif host.include?("youtube.com")
      params = Rack::Utils.parse_query(uri.query.to_s)
      return params["v"] if params["v"].present?

      path_parts = uri.path.to_s.split("/")
      marker_index = path_parts.index("embed") || path_parts.index("shorts") || path_parts.index("live")
      marker_index ? path_parts[marker_index + 1] : nil
    end
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :extract_youtube_id

  def self.merge_classes(existing, extra)
    return extra if existing.blank?
    return existing if extra.blank?

    ([existing] + extra.to_s.split).join(" ")
  end
  private_class_method :merge_classes
end
