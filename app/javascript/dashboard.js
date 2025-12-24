const applyThemePreference = () => {
  const darkMode = localStorage.getItem("dark-mode");
  const isDark = darkMode === "true";

  if (darkMode === "false" || darkMode === null) {
    document.documentElement.classList.remove("dark");
    document.documentElement.style.colorScheme = "light";
    return;
  }

  if (isDark) {
    document.documentElement.classList.add("dark");
    document.documentElement.style.colorScheme = "dark";
  }
};

const applySidebarState = () => {
  const expanded = localStorage.getItem("sidebar-expanded") === "true";
  if (expanded) {
    document.body.classList.add("sidebar-expanded");
  } else {
    document.body.classList.remove("sidebar-expanded");
  }
};

const setupCopyHelper = () => {
  window.copyToClipboard = function(button) {
    if (!button || !button.dataset) return;

    const text = button.dataset.copyText;
    if (!text || !navigator.clipboard || !navigator.clipboard.writeText) return;

    const defaultText = button.dataset.defaultText || button.textContent;
    const copiedText = button.dataset.copiedText || "Copied";
    const resetAfterMs = parseInt(button.dataset.resetAfterMs || "1500", 10);

    button.disabled = true;

    navigator.clipboard.writeText(text).then(() => {
      button.textContent = copiedText;
      button.classList.add("text-emerald-600", "dark:text-emerald-200");

      setTimeout(() => {
        button.textContent = defaultText;
        button.classList.remove("text-emerald-600", "dark:text-emerald-200");
        button.disabled = false;
      }, resetAfterMs);
    }).catch(() => {
      button.disabled = false;
    });
  };
};

const bootstrapDashboardLayout = () => {
  applyThemePreference();
  applySidebarState();
  setupCopyHelper();
};

bootstrapDashboardLayout();
