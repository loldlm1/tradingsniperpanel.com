// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

const activateLoading = (target) => {
  if (!target || target.dataset.loadingActive === "true") return;
  target.dataset.loadingActive = "true";
  target.setAttribute("aria-busy", "true");
  target.classList.add("pointer-events-none", "opacity-75");

  const label = target.querySelector("[data-loading-label]");
  const spinner = target.querySelector("[data-loading-spinner]");
  if (label) label.classList.add("hidden");
  if (spinner) spinner.classList.remove("hidden");
};

const bindLoadingButtons = () => {
  document.querySelectorAll("[data-loading-target]").forEach((el) => {
    if (el.tagName === "FORM") {
      el.addEventListener("submit", (event) => {
        const submitter = event.submitter || el.querySelector("[data-loading-target-button]") || el.querySelector("[type='submit']");
        activateLoading(submitter || el);
      });
    } else {
      el.addEventListener("click", (event) => {
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
