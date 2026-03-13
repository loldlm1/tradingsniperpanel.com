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

  const isDark = localStorage.getItem("dark-mode") === "true";
  const gridColor = isDark ? "rgba(75, 85, 99, 0.45)" : "#E5E7EB";
  const tickColor = isDark ? "#9CA3AF" : "#6B7280";
  const barColor = isDark ? "#38BDF8" : "#0EA5E9";
  const barHoverColor = isDark ? "#7DD3FC" : "#0284C7";

  if (canvas._partnerChartInstance) {
    canvas._partnerChartInstance.destroy();
  }

  canvas._partnerChartInstance = new Chart(canvas, {
    type: "bar",
    data: {
      labels: payload.labels,
      datasets: [{
        data: payload.values,
        backgroundColor: barColor,
        hoverBackgroundColor: barHoverColor,
        borderRadius: 10,
        borderSkipped: false,
        maxBarThickness: 34
      }]
    },
    options: {
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          displayColors: false,
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
          grid: { color: gridColor },
          border: { display: false },
          ticks: {
            color: tickColor,
            callback: (value) => `$${value}`
          }
        },
        x: {
          grid: { display: false },
          border: { display: false },
          ticks: { color: tickColor }
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
  schedulePartnerDashboardChart();
};

bootstrapDashboardLayout();
