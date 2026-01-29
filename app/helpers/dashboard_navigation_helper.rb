module DashboardNavigationHelper
  GROUP_LI_BASE = "pl-4 pr-3 py-2 rounded-lg mb-0.5 last:mb-0".freeze
  GROUP_ACTIVE_BG = "bg-brand-500/10 dark:bg-brand-500/20".freeze
  CHILD_SPAN_CLASSES = "text-sm font-medium lg:opacity-0 lg:sidebar-expanded:opacity-100 2xl:opacity-100 duration-200".freeze
  SIDEBAR_BADGE_CLASSES = "inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold tabular-nums leading-none shrink-0 bg-gray-100 text-gray-700 dark:bg-gray-700/60 dark:text-gray-100".freeze
  SIDEBAR_BADGE_SPACER_CLASSES = "inline-flex w-6 h-6 shrink-0".freeze

  def mosaic_sidebar_li_classes(active:)
    [GROUP_LI_BASE, (GROUP_ACTIVE_BG if active)].compact.join(" ")
  end

  def mosaic_sidebar_group_link_classes(active:)
    base = "block rounded-lg text-gray-800 dark:text-gray-100 truncate transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-gray-800"
    active ? "#{base} text-gray-900 dark:text-white" : "#{base} hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-700/50"
  end

  def mosaic_sidebar_icon_classes(active:)
    active ? "shrink-0 fill-current text-brand-600 dark:text-brand-400" : "shrink-0 fill-current text-gray-400 dark:text-gray-500"
  end

  def mosaic_sidebar_child_link_classes(active:)
    base = "block rounded-md px-2 py-1 transition-colors truncate focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500/40 focus-visible:ring-offset-2 focus-visible:ring-offset-white dark:focus-visible:ring-offset-gray-800"
    active ? "#{base} text-brand-600 dark:text-brand-300 bg-brand-500/10 dark:bg-brand-500/15" : "#{base} text-gray-500/90 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700/50"
  end

  def mosaic_sidebar_child_span_classes
    CHILD_SPAN_CLASSES
  end

  def mosaic_sidebar_badge_classes
    SIDEBAR_BADGE_CLASSES
  end

  def mosaic_sidebar_badge_spacer_classes
    SIDEBAR_BADGE_SPACER_CLASSES
  end
end
