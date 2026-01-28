const splitClasses = (value) => {
  if (!value) return [];
  return value.split(" ").map((item) => item.trim()).filter(Boolean);
};

const scopedElements = (container, selector) => {
  return Array.from(container.querySelectorAll(selector)).filter(
    (element) => element.closest("[data-pagination-container]") === container
  );
};

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

const updateButtonClasses = (button, active, activeClasses, inactiveClasses) => {
  if (!button) return;
  if (activeClasses.length) button.classList.remove(...activeClasses);
  if (inactiveClasses.length) button.classList.remove(...inactiveClasses);

  const nextClasses = active ? activeClasses : inactiveClasses;
  if (nextClasses.length) button.classList.add(...nextClasses);
  button.setAttribute("aria-current", active ? "page" : "false");
};

const setButtonDisabled = (button, disabled, disabledClasses) => {
  if (!button) return;
  button.disabled = disabled;
  button.setAttribute("aria-disabled", disabled ? "true" : "false");

  if (disabledClasses.length) {
    if (disabled) {
      button.classList.add(...disabledClasses);
    } else {
      button.classList.remove(...disabledClasses);
    }
  }
};

const bindPaginatedLists = () => {
  document.querySelectorAll("[data-pagination-container]").forEach((container) => {
    if (container.dataset.paginationBound === "true") return;
    container.dataset.paginationBound = "true";

    const items = scopedElements(container, "[data-pagination-item]");
    if (items.length === 0) return;

    const pageSize = parseInt(container.dataset.pageSize || "1", 10);
    if (!Number.isFinite(pageSize) || pageSize <= 0) return;

    const totalPages = Math.max(1, Math.ceil(items.length / pageSize));
    const activeClasses = splitClasses(container.dataset.activeClass);
    const inactiveClasses = splitClasses(container.dataset.inactiveClass);
    const disabledClasses = splitClasses(container.dataset.disabledClass);

    const pageButtons = scopedElements(container, "[data-pagination-page]");
    const prevButton = scopedElements(container, "[data-pagination-prev]")[0];
    const nextButton = scopedElements(container, "[data-pagination-next]")[0];

    let currentPage = parseInt(container.dataset.currentPage || "1", 10);
    currentPage = clamp(currentPage, 1, totalPages);

    const update = () => {
      const startIndex = (currentPage - 1) * pageSize;
      const endIndex = startIndex + pageSize;

      items.forEach((item, index) => {
        const visible = index >= startIndex && index < endIndex;
        item.classList.toggle("hidden", !visible);
      });

      pageButtons.forEach((button) => {
        const page = parseInt(button.dataset.paginationPage || "1", 10);
        updateButtonClasses(button, page === currentPage, activeClasses, inactiveClasses);
      });

      setButtonDisabled(prevButton, currentPage <= 1, disabledClasses);
      setButtonDisabled(nextButton, currentPage >= totalPages, disabledClasses);
      container.dataset.currentPage = currentPage.toString();
    };

    const goToPage = (page) => {
      currentPage = clamp(page, 1, totalPages);
      update();
    };

    pageButtons.forEach((button) => {
      button.addEventListener("click", (event) => {
        event.preventDefault();
        const page = parseInt(button.dataset.paginationPage || "1", 10);
        if (!Number.isFinite(page)) return;
        goToPage(page);
      });
    });

    if (prevButton) {
      prevButton.addEventListener("click", (event) => {
        event.preventDefault();
        goToPage(currentPage - 1);
      });
    }

    if (nextButton) {
      nextButton.addEventListener("click", (event) => {
        event.preventDefault();
        goToPage(currentPage + 1);
      });
    }

    update();
  });
};

document.addEventListener("DOMContentLoaded", bindPaginatedLists);
window.addEventListener("pageshow", bindPaginatedLists);
