module ApplicationHelper
  def locale_link_class(locale)
    base = "px-2 py-1 rounded-full text-xs font-semibold transition"
    I18n.locale.to_s == locale.to_s ? "#{base} bg-blue-500 text-white" : "#{base} text-gray-300 hover:text-white bg-gray-800/60"
  end

  def loading_label(label, loading_text: t("loading.default", default: "Processing..."))
    content_tag(:span, label, data: { loading_label: true }) +
      content_tag(:span, class: "hidden items-center justify-center gap-2", data: { loading_spinner: true }) do
        concat(content_tag(:span, "", class: "inline-block h-4 w-4 border-2 border-current border-t-transparent rounded-full animate-spin"))
        concat(content_tag(:span, loading_text, class: "text-sm"))
      end
  end
end
