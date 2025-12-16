module ApplicationHelper
  def locale_link_class(locale)
    base = "px-2 py-1 rounded-full text-xs font-semibold transition"
    I18n.locale.to_s == locale.to_s ? "#{base} bg-blue-500 text-white" : "#{base} text-gray-300 hover:text-white bg-gray-800/60"
  end
end
