const initRefundAcknowledgement = () => {
  document.querySelectorAll("[data-refund-ack-scope]").forEach((scope) => {
    if (scope.dataset.refundAckBound === "true") return;
    scope.dataset.refundAckBound = "true";

    const checkbox = scope.querySelector("[data-refund-ack-checkbox]");
    if (!checkbox) return;

    const forms = Array.from(scope.querySelectorAll("form[data-refund-ack-form]"));
    if (forms.length === 0) return;

    const updateButtons = () => {
      const acknowledged = checkbox.checked;
      forms.forEach((form) => {
        const button = form.querySelector("button[type='submit'], input[type='submit']");
        if (!button) return;
        button.disabled = !acknowledged;
        if (acknowledged) {
          button.classList.remove("opacity-60", "cursor-not-allowed");
        } else {
          button.classList.add("opacity-60", "cursor-not-allowed");
        }
      });
    };

    const ensureHiddenField = (form) => {
      let input = form.querySelector("input[name='refund_acknowledged']");
      if (!input) {
        input = document.createElement("input");
        input.type = "hidden";
        input.name = "refund_acknowledged";
        form.appendChild(input);
      }
      input.value = "1";
    };

    forms.forEach((form) => {
      form.addEventListener("submit", (event) => {
        if (!checkbox.checked) {
          event.preventDefault();
          checkbox.focus();
          return;
        }
        ensureHiddenField(form);
      });
    });

    checkbox.addEventListener("change", updateButtons);
    updateButtons();
  });
};

document.addEventListener("DOMContentLoaded", initRefundAcknowledgement);
window.addEventListener("pageshow", initRefundAcknowledgement);
