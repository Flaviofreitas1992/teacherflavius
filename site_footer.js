(function () {
  "use strict";

  function isEnrollmentLink(value) {
    if (!value) return false;
    try {
      const url = new URL(value, window.location.href);
      return url.origin === window.location.origin &&
        (url.pathname === "/matricula/" || url.pathname === "/matricula.html");
    } catch (error) {
      return false;
    }
  }

  function removeEnrollmentLinks(root) {
    const target = root && root.querySelectorAll ? root : document;
    target.querySelectorAll("a[href]").forEach(function (link) {
      if (isEnrollmentLink(link.getAttribute("href"))) link.remove();
    });
  }

  function installEnrollmentLinkGuard() {
    removeEnrollmentLinks(document);
    const observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        mutation.addedNodes.forEach(function (node) {
          if (!node || node.nodeType !== 1) return;
          if (node.matches && node.matches("a[href]") && isEnrollmentLink(node.getAttribute("href"))) {
            node.remove();
            return;
          }
          removeEnrollmentLinks(node);
        });
      });
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

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

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", installEnrollmentLinkGuard, { once: true });
  } else {
    installEnrollmentLinkGuard();
  }

  loadScript("teacher-flavius-clean-urls", "/clean_urls.js?v=20260819-1", function () {
    loadScript("teacher-flavius-google-only-access", "/google_only_access.js?v=20260819-1", function () {
      loadScript("teacher-flavius-site-footer-core", "/site_footer_core.js?v=20260819-2", function () {
        removeEnrollmentLinks(document);
      });
    });
  });
})();
