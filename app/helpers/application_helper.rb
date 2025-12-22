module ApplicationHelper
  def locale_link_class(locale)
    base = "px-2 py-1 rounded-full text-xs font-semibold transition"
    I18n.locale.to_s == locale.to_s ? "#{base} bg-blue-500 text-white" : "#{base} text-gray-300 hover:text-white bg-gray-800/60"
  end

  def loading_label(label, loading_text: t("loading.default", default: "Processing..."))
    content_tag(:span, label, data: { loading_label: true }) +
      content_tag(:span, class: "inline-flex items-center justify-center gap-2", data: { loading_spinner: true }, role: "status", "aria-live": "polite", hidden: true) do
        spinner_circle = content_tag(:span, "", class: "loading-spinner inline-block h-4 w-4 rounded-full border-2 border-solid border-current border-t-transparent align-middle", style: "border-color: currentColor; border-top-color: transparent;")
        concat(spinner_circle)
        concat(content_tag(:span, loading_text, class: "text-sm"))
      end
  end
end
