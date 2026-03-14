const applySidebarState = () => {
  const expanded = localStorage.getItem("sidebar-expanded") === "true";
  if (expanded) {
    document.body.classList.add("sidebar-expanded");
  } else {
    document.body.classList.remove("sidebar-expanded");
  }
};

const COPY_SUCCESS_CLASSES = ["text-emerald-600", "dark:text-emerald-200"];
const COPY_FAILURE_CLASSES = ["text-rose-600", "dark:text-rose-300"];

const copyTextToClipboard = (text) => {
  if (!text) return Promise.reject(new Error("empty_copy_text"));

  if (window.isSecureContext && navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
    return navigator.clipboard.writeText(text);
  }

  return new Promise((resolve, reject) => {
    const fallback = document.createElement("textarea");
    fallback.value = text;
    fallback.setAttribute("readonly", "");
    fallback.style.position = "fixed";
    fallback.style.top = "-9999px";
    fallback.style.left = "-9999px";
    document.body.appendChild(fallback);
    fallback.focus();
    fallback.select();

    let copied = false;
    try {
      copied = document.execCommand("copy");
    } catch (error) {
      copied = false;
    } finally {
      document.body.removeChild(fallback);
    }

    if (copied) {
      resolve();
    } else {
      reject(new Error("clipboard_unavailable"));
    }
  });
};

const applyCopyFeedback = ({ button, label, classes, resetAfterMs, defaultText }) => {
  button.textContent = label;
  button.classList.remove(...COPY_SUCCESS_CLASSES, ...COPY_FAILURE_CLASSES);
  button.classList.add(...classes);

  window.setTimeout(() => {
    button.textContent = defaultText;
    button.classList.remove(...COPY_SUCCESS_CLASSES, ...COPY_FAILURE_CLASSES);
    button.disabled = false;
  }, resetAfterMs);
};

const setupCopyHelper = () => {
  const copyFromButton = (button) => {
    if (!button || !button.dataset) return;

    const text = button.dataset.copyText;
    if (!text) return;

    const defaultText = button.dataset.defaultText || button.textContent;
    const copiedText = button.dataset.copiedText || "Copied";
    const copyFailedText = button.dataset.copyFailedText || "Copy failed";
    const parsedResetMs = parseInt(button.dataset.resetAfterMs || "1500", 10);
    const resetAfterMs = Number.isFinite(parsedResetMs) ? parsedResetMs : 1500;

    button.disabled = true;
    button.classList.remove(...COPY_SUCCESS_CLASSES, ...COPY_FAILURE_CLASSES);

    copyTextToClipboard(text).then(() => {
      applyCopyFeedback({
        button,
        label: copiedText,
        classes: COPY_SUCCESS_CLASSES,
        resetAfterMs,
        defaultText
      });
    }).catch(() => {
      applyCopyFeedback({
        button,
        label: copyFailedText,
        classes: COPY_FAILURE_CLASSES,
        resetAfterMs,
        defaultText
      });
    });
  };

  window.copyToClipboard = function(button) {
    copyFromButton(button);
  };

  document.querySelectorAll("[data-copy-button='true']").forEach((button) => {
    if (button.dataset.copyBound === "true") return;

    button.dataset.copyBound = "true";
    button.addEventListener("click", () => copyFromButton(button));
  });
};

const setupGuideCodeCopy = () => {
  const container = document.querySelector("[data-scrollspy-container]");
  if (!container) return;

  const copyLabel = container.dataset.copyLabel || "Copy";
  const copiedLabel = container.dataset.copiedLabel || "Copied";

  container.querySelectorAll("pre").forEach((pre) => {
    if (pre.querySelector("[data-guide-copy-button]")) return;

    const button = document.createElement("button");
    button.type = "button";
    button.dataset.guideCopyButton = "true";
    button.className = "absolute top-2 right-2 text-xs px-2 py-1 rounded bg-slate-800 text-white hover:bg-slate-700";
    button.textContent = copyLabel;

    button.addEventListener("click", () => {
      const code = pre.querySelector("code");
      const text = code ? code.innerText : pre.innerText;
      if (!navigator.clipboard || !navigator.clipboard.writeText) return;

      navigator.clipboard.writeText(text).then(() => {
        button.textContent = copiedLabel;
        setTimeout(() => {
          button.textContent = copyLabel;
        }, 1200);
      });
    });

    pre.classList.add("relative");
    pre.appendChild(button);
  });
};

const setupGuideScrollSpy = () => {
  const container = document.querySelector("[data-scrollspy-container]");
  if (!container || container.dataset.scrollSpyBound === "true") return;

  const targets = container.querySelectorAll("[data-scrollspy-target]");
  const links = document.querySelectorAll("[data-scrollspy-link]");
  if (targets.length < 1 || links.length < 1) return;

  const targetMargin = 120;
  let currentActive = -1;

  const activate = (index) => {
    if (!links[index]) return;
    links[index].classList.add("scrollspy-active");
  };

  const clearAll = () => {
    links.forEach((link) => link.classList.remove("scrollspy-active"));
  };

  const onScroll = () => {
    const positions = Array.from(targets).map((target) => target.offsetTop - targetMargin);
    const current = positions.reduce((acc, pos, idx) => (window.scrollY >= pos ? idx : acc), 0);
    if (current !== currentActive) {
      clearAll();
      activate(current);
      currentActive = current;
    }
  };

  container.dataset.scrollSpyBound = "true";
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();
};

const normalizeFilterText = (value) => {
  if (value === null || value === undefined) return "";
  return value.toString().trim().toLowerCase();
};

const formatFilterTemplate = (template, replacements) => {
  if (!template) return "";

  return Object.entries(replacements).reduce(
    (output, [key, value]) => output.replace(new RegExp(`%\\{${key}\\}`, "g"), value),
    template
  );
};

const setupCourseProgressTracking = () => {
  const video = document.querySelector("[data-course-progress]");
  if (!video || video.dataset.progressBound === "true") return;

  const progressUrl = video.dataset.courseProgressUrl;
  if (!progressUrl) return;

  const throttleMs = parseInt(video.dataset.courseProgressThrottle || "15000", 10);
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
  let lastSentAt = 0;

  const sendProgress = (force = false) => {
    const now = Date.now();
    if (!force && now - lastSentAt < throttleMs) return;
    lastSentAt = now;

    const payload = { progress_seconds: Math.floor(video.currentTime || 0) };
    if (force) payload.completed = video.ended;

    fetch(progressUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken
      },
      credentials: "same-origin",
      body: JSON.stringify(payload)
    }).catch(() => {});
  };

  video.dataset.progressBound = "true";
  video.addEventListener("timeupdate", () => sendProgress(false));
  video.addEventListener("ended", () => sendProgress(true));
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden") sendProgress(true);
  });
  window.addEventListener("beforeunload", () => sendProgress(true));
};

const setupPartnerReferralsFilter = () => {
  const container = document.querySelector("[data-partner-referrals-filter='true']");
  if (!container || container.dataset.partnerReferralsBound === "true") return;

  container.dataset.partnerReferralsBound = "true";

  const form = container.querySelector("[data-partner-referrals-form='true']");
  const input = container.querySelector("[data-partner-referrals-input='true']");
  const clearLink = container.querySelector("[data-partner-referrals-clear='true']");
  const countEl = container.querySelector("[data-partner-referrals-count='true']");
  const pagination = container.querySelector("[data-partner-referrals-pagination='true']");
  const emptyMobile = container.querySelector("[data-partner-referrals-empty-mobile='true']");
  const emptyDesktop = container.querySelector("[data-partner-referrals-empty-desktop='true']");

  const groupedItems = new Map();
  container.querySelectorAll("[data-partner-referral-item='true']").forEach((item, index) => {
    const key = item.dataset.partnerReferralKey || `referral-${index}`;
    if (!groupedItems.has(key)) {
      groupedItems.set(key, {
        text: normalizeFilterText(item.dataset.filterText),
        nodes: []
      });
    }

    groupedItems.get(key).nodes.push(item);
  });

  if (!input || groupedItems.size === 0) return;

  const totalTemplate = countEl?.dataset.totalTemplate || "%{count}";
  const filteredTemplate = countEl?.dataset.filteredTemplate || "%{count}";

  const updateCount = (query, matchCount) => {
    if (!countEl) return;

    countEl.textContent = formatFilterTemplate(query.length > 0 ? filteredTemplate : totalTemplate, {
      count: query.length > 0 ? matchCount.toString() : groupedItems.size.toString(),
      query: input.value.trim()
    });
  };

  const updateEmptyStates = (query, matchCount) => {
    const showEmpty = query.length > 0 && matchCount === 0;
    if (emptyMobile) emptyMobile.classList.toggle("hidden", !showEmpty);
    if (emptyDesktop) emptyDesktop.classList.toggle("hidden", !showEmpty);
  };

  const applyFilter = () => {
    const query = normalizeFilterText(input.value);
    let matchCount = 0;

    groupedItems.forEach((group) => {
      const matches = query.length === 0 || group.text.includes(query);
      group.nodes.forEach((node) => {
        node.classList.toggle("hidden", !matches);
      });
      if (matches) matchCount += 1;
    });

    updateCount(query, matchCount);
    updateEmptyStates(query, matchCount);

    if (pagination) {
      pagination.classList.toggle("hidden", query.length > 0);
    }

    if (clearLink) {
      clearLink.classList.toggle("hidden", query.length === 0);
    }
  };

  form?.addEventListener("submit", (event) => {
    event.preventDefault();
    applyFilter();
  });

  input.addEventListener("input", () => {
    applyFilter();
  });

  clearLink?.addEventListener("click", (event) => {
    event.preventDefault();
    input.value = "";
    applyFilter();
    input.focus();
  });

  applyFilter();
};

const initPartnerDashboardChart = () => {
  const canvas = document.querySelector("#partner-paid-earnings-chart[data-partner-chart]");
  if (!canvas || !window.Chart) return;

  let payload;
  try {
    payload = JSON.parse(canvas.dataset.partnerChart || "{}");
  } catch (error) {
    payload = null;
  }

  if (!payload || !Array.isArray(payload.labels) || !Array.isArray(payload.values)) return;

  const readCssVar = (name, fallback) => {
    const value = getComputedStyle(document.body).getPropertyValue(name).trim();
    return value || fallback;
  };

  const hexToRGB = (hex) => {
    if (!hex) return "0, 0, 0";
    const normalized = hex.replace("#", "");
    if (normalized.length === 3) {
      return `${parseInt(normalized[0] + normalized[0], 16)}, ${parseInt(normalized[1] + normalized[1], 16)}, ${parseInt(normalized[2] + normalized[2], 16)}`;
    }
    if (normalized.length === 6) {
      return `${parseInt(normalized.slice(0, 2), 16)}, ${parseInt(normalized.slice(2, 4), 16)}, ${parseInt(normalized.slice(4, 6), 16)}`;
    }
    return "0, 0, 0";
  };

  const withAlpha = (color, alpha) => {
    if (!color) return `rgba(0, 0, 0, ${alpha})`;
    if (color.startsWith("rgba(")) return color;
    if (color.startsWith("rgb(")) {
      return color.replace("rgb(", "rgba(").replace(")", `, ${alpha})`);
    }
    if (color.startsWith("#")) {
      return `rgba(${hexToRGB(color)}, ${alpha})`;
    }
    return color;
  };

  const isDark = localStorage.getItem("dark-mode") === "true";
  const gridColor = isDark ? "rgba(71, 85, 105, 0.35)" : "rgba(148, 163, 184, 0.22)";
  const tickColor = isDark ? "#94A3B8" : "#64748B";
  const lineColor = isDark ? readCssVar("--brand-400", "#A78BFA") : readCssVar("--brand-500", "#8B5CF6");
  const pointBorderColor = isDark ? "#0F172A" : "#FFFFFF";
  const ctx = canvas.getContext("2d");
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height || 320);
  gradient.addColorStop(0, withAlpha(lineColor, isDark ? 0.36 : 0.28));
  gradient.addColorStop(1, withAlpha(lineColor, 0.02));
  const locale = document.documentElement.lang || "en-US";

  if (canvas._partnerChartInstance) {
    canvas._partnerChartInstance.destroy();
  }

  canvas._partnerChartInstance = new Chart(canvas, {
    type: "line",
    data: {
      labels: payload.labels,
      datasets: [{
        data: payload.values,
        fill: true,
        backgroundColor: gradient,
        borderColor: lineColor,
        borderWidth: 3,
        tension: 0.38,
        pointRadius: 4,
        pointHoverRadius: 5,
        pointBackgroundColor: lineColor,
        pointHoverBackgroundColor: lineColor,
        pointBorderColor,
        pointBorderWidth: 2
      }]
    },
    options: {
      maintainAspectRatio: false,
      interaction: {
        intersect: false,
        mode: "index"
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          displayColors: false,
          backgroundColor: isDark ? "#0F172A" : "#FFFFFF",
          titleColor: isDark ? "#E2E8F0" : "#0F172A",
          bodyColor: isDark ? "#CBD5E1" : "#334155",
          borderColor: isDark ? withAlpha(lineColor, 0.18) : "rgba(148, 163, 184, 0.22)",
          borderWidth: 1,
          padding: 12,
          callbacks: {
            label: (context) => new Intl.NumberFormat("en-US", {
              style: "currency",
              currency: "USD",
              minimumFractionDigits: 2,
              maximumFractionDigits: 2
            }).format(Number(context.parsed.y || 0))
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          grid: {
            color: gridColor,
            drawTicks: false
          },
          border: { display: false },
          ticks: {
            color: tickColor,
            padding: 10,
            callback: (value) => new Intl.NumberFormat(locale, {
              style: "currency",
              currency: "USD",
              minimumFractionDigits: 0,
              maximumFractionDigits: 0
            }).format(Number(value || 0))
          }
        },
        x: {
          grid: { display: false },
          border: { display: false },
          ticks: {
            color: tickColor,
            padding: 10
          }
        }
      }
    }
  });
};

const schedulePartnerDashboardChart = () => {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPartnerDashboardChart, { once: true });
  } else {
    initPartnerDashboardChart();
  }

  document.addEventListener("darkMode", () => {
    initPartnerDashboardChart();
  });
};

const bootstrapDashboardLayout = () => {
  applySidebarState();
  setupCopyHelper();
  setupGuideCodeCopy();
  setupGuideScrollSpy();
  setupCourseProgressTracking();
  setupPartnerReferralsFilter();
  schedulePartnerDashboardChart();
};

bootstrapDashboardLayout();
