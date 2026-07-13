(function ($) {
  "use strict";

  function initializeManualSubscriptionUserSearch() {
    document.querySelectorAll("[data-manual-subscription-user-search]").forEach(function (input) {
      if (input.dataset.userSearchInitialized === "true") return;

      var hiddenInput = document.getElementById(input.dataset.userIdInput);
      var searchUrl = input.dataset.searchUrl;
      if (!hiddenInput || !searchUrl) return;

      input.dataset.userSearchInitialized = "true";
      var autocomplete = $(input).autocomplete({
        delay: 180,
        minLength: 2,
        source: function (request, response) {
          $.getJSON(searchUrl, { q: request.term })
            .done(response)
            .fail(function () { response([]); });
        },
        select: function (event, ui) {
          event.preventDefault();
          hiddenInput.value = ui.item.id;
          input.value = ui.item.value;
        },
        change: function (_event, ui) {
          if (!ui.item) hiddenInput.value = "";
        }
      });

      autocomplete.autocomplete("widget").addClass("manual-subscription-user-results");
      input.addEventListener("input", function () {
        hiddenInput.value = "";
      });
    });
  }

  $(initializeManualSubscriptionUserSearch);
  document.addEventListener("turbo:load", initializeManualSubscriptionUserSearch);
})(window.jQuery);
