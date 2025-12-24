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

applyThemePreference();
