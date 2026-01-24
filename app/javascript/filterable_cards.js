const normalizeValue = (value) => {
  if (value === null || value === undefined) return "";
  return value.toString().trim().toLowerCase();
};

const splitClasses = (value) => {
  if (!value) return [];
  return value.split(" ").map((item) => item.trim()).filter(Boolean);
};

const updateChipState = (chip, active) => {
  if (!chip) return;

  const activeClasses = splitClasses(chip.dataset.filterActiveClass);
  const defaultClasses = splitClasses(chip.dataset.filterDefaultClass);

  if (activeClasses.length) chip.classList.remove(...activeClasses);
  if (defaultClasses.length) chip.classList.remove(...defaultClasses);

  const nextClasses = active ? activeClasses : defaultClasses;
  if (nextClasses.length) chip.classList.add(...nextClasses);

  chip.setAttribute("aria-pressed", active ? "true" : "false");
};

const shouldHandleClick = (event) => {
  if (!event) return false;
  if (event.defaultPrevented) return false;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false;
  if (event.button && event.button !== 0) return false;
  return true;
};

const bindFilterableCards = () => {
  document.querySelectorAll("[data-filterable]").forEach((container) => {
    if (container.dataset.filterableBound === "true") return;
    container.dataset.filterableBound = "true";

    const form = container.querySelector("[data-filter-form]");
    const input = container.querySelector("[data-filter-input]");
    const countEl = container.querySelector("[data-filter-count]");
    const pagination = container.querySelector("[data-filter-pagination]");
    const tagChips = Array.from(container.querySelectorAll("[data-filter-tag]"));
    const allChip = container.querySelector("[data-filter-all]");
    const items = Array.from(container.querySelectorAll("[data-filter-item]"));

    const pageSize = parseInt(container.dataset.pageSize || "0", 10);
    const currentPage = parseInt(container.dataset.currentPage || "1", 10);
    const pageOffset = Math.max(0, (currentPage - 1) * pageSize);

    let activeTag = normalizeValue(container.dataset.activeTag);

    if (input && container.dataset.activeQuery !== undefined) {
      input.value = container.dataset.activeQuery;
    }

    const updateCount = (count) => {
      if (!countEl) return;
      const template = countEl.dataset.countTemplate || "%{count}";
      const formatted = template.includes("%{count}") ? template.replace(/%\{count\}/g, count) : `${count}`;
      countEl.textContent = formatted;
    };

    const applyFilter = () => {
      const query = normalizeValue(input ? input.value : container.dataset.activeQuery);
      const tag = normalizeValue(activeTag);
      const filtering = query.length > 0 || tag.length > 0;
      let matchCount = 0;

      items.forEach((item, position) => {
        const text = normalizeValue(item.dataset.filterText);
        const tags = (item.dataset.filterTags || "").split("|").map(normalizeValue).filter(Boolean);
        const itemIndex = parseInt(item.dataset.filterIndex || "", 10);
        const fallbackIndex = Number.isNaN(itemIndex) ? position : itemIndex;

        let matches = true;
        if (query.length > 0) {
          matches = text.includes(query);
        }
        if (matches && tag.length > 0) {
          matches = tags.includes(tag);
        }

        let visible = matches;
        if (!filtering) {
          visible = pageSize > 0 ? (fallbackIndex >= pageOffset && fallbackIndex < pageOffset + pageSize) : true;
        }

        if (filtering && matches) matchCount += 1;
        item.classList.toggle("hidden", !visible);
      });

      updateCount(filtering ? matchCount : items.length);
      if (pagination) pagination.classList.toggle("hidden", filtering);

      tagChips.forEach((chip) => updateChipState(chip, normalizeValue(chip.dataset.filterTag) === tag && tag.length > 0));
      if (allChip) updateChipState(allChip, tag.length === 0);

      container.dataset.activeTag = tag;
      container.dataset.activeQuery = query;
    };

    if (form) {
      form.addEventListener("submit", (event) => {
        event.preventDefault();
        applyFilter();
      });
    }

    if (input) {
      input.addEventListener("input", () => {
        applyFilter();
      });
    }

    tagChips.forEach((chip) => {
      chip.addEventListener("click", (event) => {
        if (!shouldHandleClick(event)) return;
        event.preventDefault();
        activeTag = normalizeValue(chip.dataset.filterTag);
        applyFilter();
      });
    });

    if (allChip) {
      allChip.addEventListener("click", (event) => {
        if (!shouldHandleClick(event)) return;
        event.preventDefault();
        activeTag = "";
        applyFilter();
      });
    }

    applyFilter();
  });
};

document.addEventListener("DOMContentLoaded", bindFilterableCards);
window.addEventListener("pageshow", bindFilterableCards);
