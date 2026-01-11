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

const bootstrapDashboardLayout = () => {
  applySidebarState();
  setupCopyHelper();
  setupGuideCodeCopy();
  setupGuideScrollSpy();
  setupCourseProgressTracking();
};

bootstrapDashboardLayout();
