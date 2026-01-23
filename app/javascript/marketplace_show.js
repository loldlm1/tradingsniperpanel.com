const parseBoolean = (value) => value === "true";

const formatCurrency = (cents, locale, currency) => {
  const value = (Number(cents) || 0) / 100;
  try {
    return new Intl.NumberFormat(locale || "en", {
      style: "currency",
      currency: (currency || "USD").toUpperCase(),
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  } catch (error) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(value);
  }
};

const ADD_CLASSES = [
  "btn",
  "bg-gray-900",
  "text-gray-100",
  "hover:bg-gray-800",
  "dark:bg-gray-100",
  "dark:text-gray-800",
  "dark:hover:bg-white"
];

const ADDED_CLASSES = [
  "inline-flex",
  "items-center",
  "justify-center",
  "text-xs",
  "font-medium",
  "px-3",
  "py-1.5",
  "rounded-full",
  "bg-gray-100",
  "dark:bg-gray-700/60",
  "text-gray-400",
  "dark:text-gray-500"
];

const DISABLED_CLASSES = ["opacity-60", "cursor-not-allowed"];

const applyButtonState = (button, selected) => {
  if (!button) return;

  button.classList.remove(...ADD_CLASSES, ...ADDED_CLASSES);
  if (selected) {
    button.classList.add(...ADDED_CLASSES);
    button.textContent = button.dataset.addonLabelAdded || "Added";
    button.setAttribute("aria-pressed", "true");
  } else {
    button.classList.add(...ADD_CLASSES);
    button.textContent = button.dataset.addonLabelAdd || "Add";
    button.setAttribute("aria-pressed", "false");
  }
};

const updateCheckoutButton = (button, enabled) => {
  if (!button) return;

  button.disabled = !enabled;
  if (enabled) {
    button.classList.remove(...DISABLED_CLASSES);
    button.textContent = button.dataset.checkoutLabel || button.textContent;
  } else {
    button.classList.add(...DISABLED_CLASSES);
    button.textContent = button.dataset.emptyLabel || button.textContent;
  }
};

const initMarketplaceCart = () => {
  document.querySelectorAll("[data-marketplace-cart]").forEach((form) => {
    if (form.dataset.cartBound === "true") return;
    form.dataset.cartBound = "true";

    const basePriceCents = Number(form.dataset.basePriceCents || 0);
    const baseRequired = parseBoolean(form.dataset.baseRequired);
    const checkoutLocked = parseBoolean(form.dataset.checkoutLocked);
    const locale = form.dataset.locale || "en";
    const currency = form.dataset.currency || "USD";

    const rows = Array.from(form.querySelectorAll("[data-addon-row]"));
    const keysInput = form.querySelector("[data-addon-keys-input]");
    const subtotalEl = form.querySelector("[data-addon-subtotal]");
    const totalEl = form.querySelector("[data-cart-total]");
    const progressCountEl = form.querySelector("[data-addon-progress-count]");
    const progressBar = form.querySelector("[data-addon-progress-bar]");
    const submitButton = form.querySelector("[data-cart-submit]");

    const refresh = () => {
      const selectedRows = rows.filter((row) => parseBoolean(row.dataset.addonSelected));
      const selectedKeys = selectedRows.map((row) => row.dataset.addonKey).filter(Boolean);
      const addonSubtotal = selectedRows.reduce((sum, row) => sum + Number(row.dataset.addonPriceCents || 0), 0);
      const totalCents = addonSubtotal + (baseRequired ? basePriceCents : 0);

      if (keysInput) keysInput.value = selectedKeys.join(",");
      if (subtotalEl) subtotalEl.textContent = formatCurrency(addonSubtotal, locale, currency);
      if (totalEl) totalEl.textContent = formatCurrency(totalCents, locale, currency);
      if (progressCountEl) progressCountEl.textContent = `${selectedRows.length}/${rows.length}`;
      if (progressBar) {
        const percent = rows.length ? Math.round((selectedRows.length / rows.length) * 100) : 0;
        progressBar.style.width = `${percent}%`;
      }

      if (submitButton) {
        const template = submitButton.dataset.checkoutLabelTemplate;
        if (template) {
          submitButton.dataset.checkoutLabel = template.replace(
            "%{total}",
            formatCurrency(totalCents, locale, currency)
          );
        }

        if (checkoutLocked) {
          updateCheckoutButton(submitButton, false);
        } else {
          updateCheckoutButton(submitButton, totalCents > 0);
        }
      }
    };

    rows.forEach((row) => {
      const button = row.querySelector("[data-addon-toggle]");
      const selected = parseBoolean(row.dataset.addonSelected);
      applyButtonState(button, selected);

      if (button) {
        button.addEventListener("click", () => {
          const nextSelected = !parseBoolean(row.dataset.addonSelected);
          row.dataset.addonSelected = nextSelected;
          applyButtonState(button, nextSelected);
          refresh();
        });
      }
    });

    refresh();
  });
};

document.addEventListener("DOMContentLoaded", initMarketplaceCart);
window.addEventListener("pageshow", initMarketplaceCart);
