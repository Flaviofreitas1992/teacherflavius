(function () {
  "use strict";

  function loadScript(id, src, callback) {
    const existing = document.getElementById(id);
    if (existing) {
      if (callback) callback();
      return;
    }
    const script = document.createElement("script");
    script.id = id;
    script.src = src;
    script.async = false;
    if (callback) {
      script.onload = callback;
      script.onerror = callback;
    }
    document.head.appendChild(script);
  }

  loadScript("teacher-flavius-clean-urls", "/clean_urls.js?v=20260819-1", function () {
    loadScript("teacher-flavius-site-footer-core", "/site_footer_core.js?v=20260819-1");
  });
})();