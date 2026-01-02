// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

const resetLoadingButtons = () => {
  document.querySelectorAll("[data-loading-target]").forEach((el) => {
    delete el.dataset.loadingActive;
    el.removeAttribute("aria-busy");
    el.classList.remove("pointer-events-none", "opacity-75");
    const label = el.querySelector("[data-loading-label]");
    const spinner = el.querySelector("[data-loading-spinner]");
    if (label) {
      label.hidden = false;
      label.classList.remove("hidden");
    }
    if (spinner) {
      spinner.hidden = true;
      spinner.classList.add("hidden");
    }
  });
};

const activateLoading = (target) => {
  if (!target || target.dataset.loadingActive === "true") return;

  // Prevent locking invalid forms
  const form = target.closest("form");
  if (form && typeof form.checkValidity === "function" && !form.checkValidity()) return;

  target.dataset.loadingActive = "true";
  target.setAttribute("aria-busy", "true");
  target.classList.add("pointer-events-none", "opacity-75");

  const label = target.querySelector("[data-loading-label]");
  const spinner = target.querySelector("[data-loading-spinner]");
  if (label) {
    label.hidden = true;
    label.classList.add("hidden");
  }
  if (spinner) {
    spinner.hidden = false;
    spinner.classList.remove("hidden");
  }
};

const bindLoadingButtons = () => {
  resetLoadingButtons();

  document.querySelectorAll("[data-loading-target]").forEach((el) => {
    if (el.tagName === "FORM") {
      el.addEventListener("submit", (event) => {
        const submitter = event.submitter || el.querySelector("[data-loading-target-button]") || el.querySelector("[type='submit']");
        const confirmMessage = (submitter && submitter.dataset.confirmMessage) || el.dataset.confirmMessage;
        if (confirmMessage && !window.confirm(confirmMessage)) {
          event.preventDefault();
          return;
        }
        if (event.defaultPrevented) return;
        activateLoading(submitter || el);
      });
    } else {
      el.addEventListener("click", (event) => {
        const confirmMessage = el.dataset.confirmMessage;
        if (confirmMessage && !window.confirm(confirmMessage)) {
          event.preventDefault();
          return;
        }
        if (el.tagName === "A") {
          const href = el.getAttribute("href") || "";
          if (href.startsWith("#")) return; // skip intra-page anchors
        }
        activateLoading(el);
      });
    }
  });
};

document.addEventListener("DOMContentLoaded", bindLoadingButtons);
window.addEventListener("pageshow", bindLoadingButtons);
