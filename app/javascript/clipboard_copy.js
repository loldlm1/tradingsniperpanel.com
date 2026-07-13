const SUCCESS_CLASSES = ["text-emerald-600", "dark:text-emerald-200"];
const FAILURE_CLASSES = ["text-rose-600", "dark:text-rose-300"];

const copyTextFallback = (text) => {
  return new Promise((resolve, reject) => {
    const fallback = document.createElement("textarea");
    fallback.value = text;
    fallback.setAttribute("readonly", "");
    fallback.style.position = "fixed";
    fallback.style.top = "-9999px";
    document.body.appendChild(fallback);
    fallback.focus();
    fallback.select();

    let copied = false;
    try {
      copied = document.execCommand("copy");
    } finally {
      fallback.remove();
    }

    if (copied) {
      resolve();
    } else {
      reject(new Error("clipboard_unavailable"));
    }
  });
};

const copyText = (text) => {
  if (!text) return Promise.reject(new Error("empty_copy_text"));

  if (window.isSecureContext && navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text).catch(() => copyTextFallback(text));
  }

  return copyTextFallback(text);
};

const showFeedback = (button, label, classes, defaultText, resetAfterMs) => {
  button.textContent = label;
  button.classList.remove(...SUCCESS_CLASSES, ...FAILURE_CLASSES);
  button.classList.add(...classes);

  window.setTimeout(() => {
    button.textContent = defaultText;
    button.classList.remove(...SUCCESS_CLASSES, ...FAILURE_CLASSES);
    button.disabled = false;
  }, resetAfterMs);
};

const copyFromButton = (button) => {
  const text = button.dataset.copyText;
  if (!text) return;

  const defaultText = button.dataset.defaultText || button.textContent;
  const resetAfterMs = Number.parseInt(button.dataset.resetAfterMs || "1500", 10) || 1500;
  button.disabled = true;

  copyText(text).then(() => {
    showFeedback(
      button,
      button.dataset.copiedText || "Copied",
      SUCCESS_CLASSES,
      defaultText,
      resetAfterMs
    );
  }).catch(() => {
    showFeedback(
      button,
      button.dataset.copyFailedText || "Copy failed",
      FAILURE_CLASSES,
      defaultText,
      resetAfterMs
    );
  });
};

const bindCopyButtons = () => {
  document.querySelectorAll("[data-copy-button='true']").forEach((button) => {
    if (button.dataset.copyBound === "true") return;

    button.dataset.copyBound = "true";
    button.addEventListener("click", () => copyFromButton(button));
  });
};

document.addEventListener("DOMContentLoaded", bindCopyButtons);
window.addEventListener("pageshow", bindCopyButtons);
