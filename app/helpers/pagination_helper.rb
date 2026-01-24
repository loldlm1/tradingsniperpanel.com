module PaginationHelper
  def pagy_mosaic_nav(pagy)
    return "".html_safe if pagy.nil? || pagy.pages <= 1

    series = pagy.send(:series)
    first_page = series.find { |item| item.is_a?(Integer) }
    last_page = series.reverse.find { |item| item.is_a?(Integer) }

    content_tag(:div, class: "mt-8") do
      content_tag(:div, class: "flex justify-center") do
        content_tag(:nav, class: "flex", role: "navigation", aria: { label: t("dashboard.pagination.nav_label") }) do
          concat(pagy_mosaic_prev(pagy))
          concat(pagy_mosaic_pages(pagy, series, first_page, last_page))
          concat(pagy_mosaic_next(pagy))
        end
      end
    end
  end

  private

  def pagy_mosaic_prev(pagy)
    wrapper_class = "mr-2"
    disabled_class = "inline-flex items-center justify-center rounded-lg leading-5 px-2.5 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700/60 text-gray-300 dark:text-gray-600"
    enabled_class = "inline-flex items-center justify-center rounded-lg leading-5 px-2.5 py-2 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-900 border border-gray-200 dark:border-gray-700/60 text-violet-500 shadow-xs"

    content_tag(:div, class: wrapper_class) do
      if pagy.previous
        link_to(pagy_url_for(pagy, pagy.previous), class: enabled_class, "aria-label": t("dashboard.pagination.prev")) do
          concat(content_tag(:span, t("dashboard.pagination.prev"), class: "sr-only"))
          concat(pagy_mosaic_prev_icon)
        end
      else
        content_tag(:span, class: disabled_class, "aria-disabled": "true") do
          concat(content_tag(:span, t("dashboard.pagination.prev"), class: "sr-only"))
          concat(pagy_mosaic_prev_icon)
        end
      end
    end
  end

  def pagy_mosaic_next(pagy)
    wrapper_class = "ml-2"
    disabled_class = "inline-flex items-center justify-center rounded-lg leading-5 px-2.5 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700/60 text-gray-300 dark:text-gray-600"
    enabled_class = "inline-flex items-center justify-center rounded-lg leading-5 px-2.5 py-2 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-900 border border-gray-200 dark:border-gray-700/60 text-violet-500 shadow-xs"

    content_tag(:div, class: wrapper_class) do
      if pagy.next
        link_to(pagy_url_for(pagy, pagy.next), class: enabled_class, "aria-label": t("dashboard.pagination.next")) do
          concat(content_tag(:span, t("dashboard.pagination.next"), class: "sr-only"))
          concat(pagy_mosaic_next_icon)
        end
      else
        content_tag(:span, class: disabled_class, "aria-disabled": "true") do
          concat(content_tag(:span, t("dashboard.pagination.next"), class: "sr-only"))
          concat(pagy_mosaic_next_icon)
        end
      end
    end
  end

  def pagy_mosaic_pages(pagy, series, first_page, last_page)
    list_class = "inline-flex text-sm font-medium -space-x-px rounded-lg shadow-xs"
    active_class = "inline-flex items-center justify-center leading-5 px-3.5 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700/60 text-violet-500"
    default_class = "inline-flex items-center justify-center leading-5 px-3.5 py-2 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-900 border border-gray-200 dark:border-gray-700/60 text-gray-600 dark:text-gray-300"
    gap_class = "inline-flex items-center justify-center leading-5 px-3.5 py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700/60 text-gray-400 dark:text-gray-500"

    content_tag(:ul, class: list_class) do
      safe_join(series.map do |item|
        classes = nil
        classes = "#{active_class} #{rounded_class(item, first_page, last_page)}" if item.is_a?(Integer) && item == pagy.page
        classes = "#{default_class} #{rounded_class(item, first_page, last_page)}" if item.is_a?(Integer) && item != pagy.page
        classes = gap_class if item == :gap

        content_tag(:li) do
          if item.is_a?(Integer)
            if item == pagy.page
              content_tag(:span, item, class: classes)
            else
              link_to(item, pagy_url_for(pagy, item), class: classes)
            end
          else
            content_tag(:span, "…", class: classes)
          end
        end
      end)
    end
  end

  def rounded_class(item, first_page, last_page)
    return "rounded-l-lg" if item == first_page
    return "rounded-r-lg" if item == last_page

    ""
  end

  def pagy_mosaic_prev_icon
    content_tag(:svg, class: "fill-current", width: 16, height: 16, viewBox: "0 0 16 16") do
      content_tag(:path, nil, d: "M9.4 13.4l1.4-1.4-4-4 4-4-1.4-1.4L4 8z")
    end
  end

  def pagy_mosaic_next_icon
    content_tag(:svg, class: "fill-current", width: 16, height: 16, viewBox: "0 0 16 16") do
      content_tag(:path, nil, d: "M6.6 13.4L5.2 12l4-4-4-4 1.4-1.4L12 8z")
    end
  end

  def pagy_url_for(_pagy, page)
    params_hash = params.to_unsafe_h
    page_value = page.to_i
    if page_value <= 1
      params_hash.delete("page")
    else
      params_hash["page"] = page_value
    end
    url_for(params_hash)
  end
end
