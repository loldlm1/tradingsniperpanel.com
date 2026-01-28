module DashboardNavigationHelper
  GROUP_LI_BASE = "pl-4 pr-3 py-2 rounded-lg mb-0.5 last:mb-0".freeze
  GROUP_ACTIVE_BG = "bg-linear-to-r from-teal-500/[0.12] dark:from-teal-500/[0.24] to-teal-500/[0.04]".freeze
  CHILD_SPAN_CLASSES = "text-sm font-medium lg:opacity-0 lg:sidebar-expanded:opacity-100 2xl:opacity-100 duration-200".freeze

  def mosaic_sidebar_li_classes(active:)
    [GROUP_LI_BASE, (GROUP_ACTIVE_BG if active)].compact.join(" ")
  end

  def mosaic_sidebar_group_link_classes(active:)
    base = "block text-gray-800 dark:text-gray-100 truncate transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-gray-900"
    active ? base : "#{base} hover:text-gray-900 dark:hover:text-white"
  end

  def mosaic_sidebar_icon_classes(active:)
    active ? "shrink-0 fill-current text-teal-500" : "shrink-0 fill-current text-gray-400 dark:text-gray-500"
  end

  def mosaic_sidebar_child_link_classes(active:)
    base = "block transition-colors truncate focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-gray-900"
    active ? "#{base} text-teal-500" : "#{base} text-gray-500/90 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
  end

  def mosaic_sidebar_child_span_classes
    CHILD_SPAN_CLASSES
  end
end
