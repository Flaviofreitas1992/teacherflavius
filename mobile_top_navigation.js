(function () {
  "use strict";

  if (window.__teacherFlaviusMobileTopNavigationLoaded) return;
  window.__teacherFlaviusMobileTopNavigationLoaded = true;

  var BAR_ID = "tf-mobile-top-navigation";
  var OVERLAY_ID = "tf-mobile-top-menu-overlay";
  var STYLE_ID = "tf-mobile-top-navigation-styles";
  var MOBILE_QUERY = "(max-width: 720px)";
  var SOURCE_SELECTORS = [
    "[data-mobile-menu-source]",
    ".topbar-actions",
    ".top-links",
    ".header-actions",
    ".nav-actions",
    ".top"
  ];
  var currentSource = null;
  var refreshTimer = null;

  function normalizeText(value) {
    return String(value || "").replace(/\s+/g, " ").trim();
  }

  function isActionElement(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("a[href],button,[role='button']")) return true;
    return false;
  }

  function directActions(source) {
    if (!source) return [];
    var actions = Array.from(source.children || []).filter(isActionElement);
    if (actions.length >= 2) return actions;

    return Array.from(source.querySelectorAll("a[href],button,[role='button']")).filter(function (node) {
      if (node.closest("#" + OVERLAY_ID + ",#" + BAR_ID)) return false;
      return true;
    });
  }

  function isDangerAction(action) {
    var text = normalizeText(action && action.textContent).toUpperCase();
    return text === "SAIR" || text.indexOf("LOGOUT") !== -1 || action.id === "globalLogoutButton" || action.hasAttribute("data-auth-logout");
  }

  function choosePrimary(actions) {
    var anchors = actions.filter(function (action) {
      return action.tagName === "A" && !isDangerAction(action);
    });
    if (!anchors.length) return actions.find(function (action) { return !isDangerAction(action); }) || null;

    var priorities = [
      "ÁREA DO PROFESSOR",
      "AREA DO PROFESSOR",
      "VOLTAR",
      "ÁREA DO ESTUDANTE",
      "AREA DO ESTUDANTE",
      "ÁREA DO ALUNO",
      "AREA DO ALUNO",
      "HOME",
      "INÍCIO",
      "INICIO"
    ];

    for (var i = 0; i < priorities.length; i += 1) {
      var match = anchors.find(function (action) {
        return normalizeText(action.textContent).toUpperCase().indexOf(priorities[i]) !== -1;
      });
      if (match) return match;
    }
    return anchors[0];
  }

  function candidateSources() {
    var found = [];
    SOURCE_SELECTORS.forEach(function (selector) {
      document.querySelectorAll(selector).forEach(function (source) {
        if (!found.includes(source)) found.push(source);
      });
    });
    return found.filter(function (source) {
      return directActions(source).length >= 2;
    });
  }

  function chooseSource() {
    var candidates = candidateSources();
    if (!candidates.length) return null;

    candidates.sort(function (a, b) {
      var aRect = a.getBoundingClientRect();
      var bRect = b.getBoundingClientRect();
      var aTop = Number.isFinite(aRect.top) ? aRect.top : 99999;
      var bTop = Number.isFinite(bRect.top) ? bRect.top : 99999;
      return aTop - bTop;
    });
    return candidates[0];
  }

  function installStyles() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = [
      "#" + BAR_ID + ",#" + BAR_ID + " *,#" + OVERLAY_ID + ",#" + OVERLAY_ID + " *{box-sizing:border-box}",
      "#" + BAR_ID + "{display:none}",
      "#" + OVERLAY_ID + "{display:none}",
      "@media(max-width:720px){",
      ".tf-mobile-nav-source-active{display:none!important}",
      "#" + BAR_ID + "{display:flex!important;align-items:center;justify-content:space-between;gap:10px;width:min(100%,760px);margin:0 auto 24px;padding:0 2px;position:relative;z-index:1200;font-family:var(--tf-font-body,Inter,system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif)}",
      "#" + BAR_ID + " .tf-mobile-nav-primary,#" + BAR_ID + " .tf-mobile-nav-toggle{min-height:44px;border:1px solid rgba(78,154,236,.46);border-radius:14px;background:rgba(5,66,136,.18);color:#e8f2ff;font:800 12px/1.2 var(--tf-font-display,Inter,system-ui,sans-serif);letter-spacing:.02em;text-decoration:none;box-shadow:0 8px 24px rgba(2,16,43,.16)}",
      "#" + BAR_ID + " .tf-mobile-nav-primary{display:flex;align-items:center;min-width:0;max-width:calc(100% - 116px);padding:10px 13px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}",
      "#" + BAR_ID + " .tf-mobile-nav-primary::before{content:'←';margin-right:7px;font-size:16px;line-height:1}",
      "#" + BAR_ID + " .tf-mobile-nav-toggle{display:inline-flex;align-items:center;justify-content:center;gap:7px;flex:0 0 auto;padding:10px 14px;cursor:pointer}",
      "#" + BAR_ID + " .tf-mobile-nav-toggle-icon{font-size:17px;line-height:1}",
      "#" + BAR_ID + " a:focus-visible,#" + BAR_ID + " button:focus-visible,#" + OVERLAY_ID + " a:focus-visible,#" + OVERLAY_ID + " button:focus-visible{outline:3px solid #4e9aec!important;outline-offset:3px!important}",
      "#" + OVERLAY_ID + "{position:fixed;inset:0;z-index:2147482500;align-items:flex-end;justify-content:center;padding:18px;background:rgba(2,6,23,.72);backdrop-filter:blur(6px)}",
      "#" + OVERLAY_ID + ".is-open{display:flex!important}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-sheet{width:min(100%,520px);max-height:min(78vh,680px);overflow:auto;padding:18px;border:1px solid rgba(78,154,236,.30);border-radius:24px;background:linear-gradient(155deg,#071326,#0a2956);box-shadow:0 26px 80px rgba(2,6,23,.58);font-family:var(--tf-font-body,Inter,system-ui,sans-serif)}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-head{display:flex;align-items:center;justify-content:space-between;gap:14px;margin-bottom:14px;padding:2px 2px 12px;border-bottom:1px solid rgba(148,163,184,.16)}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-title{margin:0;color:#fff;font:800 18px/1.2 var(--tf-font-display,Inter,system-ui,sans-serif)}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-close{display:grid;place-items:center;width:42px;height:42px;flex:0 0 42px;border:1px solid rgba(148,163,184,.24);border-radius:13px;background:rgba(255,255,255,.06);color:#fff;font-size:24px;line-height:1;cursor:pointer}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-list{display:grid;gap:9px}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-item{display:flex;align-items:center;justify-content:space-between;width:100%;min-height:50px;padding:12px 14px;border:1px solid rgba(78,154,236,.22);border-radius:14px;background:rgba(5,66,136,.18);color:#e2e8f0;font:750 13px/1.35 var(--tf-font-display,Inter,system-ui,sans-serif);text-align:left;text-decoration:none;cursor:pointer}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-item::after{content:'›';margin-left:12px;color:#4e9aec;font-size:21px;line-height:1}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-item.tf-mobile-menu-danger{margin-top:5px;border-color:rgba(248,113,113,.40);background:rgba(248,113,113,.10);color:#fca5a5}",
      "#" + OVERLAY_ID + " .tf-mobile-menu-item.tf-mobile-menu-danger::after{content:'';margin:0}",
      "body.tf-mobile-menu-open{overflow:hidden!important}",
      "}",
      "@media(max-width:380px){#" + BAR_ID + " .tf-mobile-nav-primary,#" + BAR_ID + " .tf-mobile-nav-toggle{min-height:42px;font-size:11px}#" + BAR_ID + " .tf-mobile-nav-primary{max-width:calc(100% - 105px);padding-inline:10px}#" + BAR_ID + " .tf-mobile-nav-toggle{padding-inline:11px}}",
      "@media(prefers-reduced-motion:reduce){#" + OVERLAY_ID + "{backdrop-filter:none}}",
      "@media print{#" + BAR_ID + ",#" + OVERLAY_ID + "{display:none!important}.tf-mobile-nav-source-active{display:flex!important}}"
    ].join("");
    document.head.appendChild(style);
  }

  function closeMenu() {
    var overlay = document.getElementById(OVERLAY_ID);
    var toggle = document.querySelector("#" + BAR_ID + " .tf-mobile-nav-toggle");
    if (overlay) overlay.classList.remove("is-open");
    document.body.classList.remove("tf-mobile-menu-open");
    if (toggle) {
      toggle.setAttribute("aria-expanded", "false");
      toggle.focus({ preventScroll: true });
    }
  }

  function openMenu() {
    var overlay = document.getElementById(OVERLAY_ID);
    var toggle = document.querySelector("#" + BAR_ID + " .tf-mobile-nav-toggle");
    if (!overlay) return;
    overlay.classList.add("is-open");
    document.body.classList.add("tf-mobile-menu-open");
    if (toggle) toggle.setAttribute("aria-expanded", "true");
    var firstItem = overlay.querySelector(".tf-mobile-menu-item,.tf-mobile-menu-close");
    if (firstItem) firstItem.focus({ preventScroll: true });
  }

  function proxyAction(original) {
    var label = normalizeText(original.textContent) || original.getAttribute("aria-label") || "Abrir";
    var proxy;

    if (original.tagName === "A" && original.getAttribute("href")) {
      proxy = document.createElement("a");
      proxy.href = original.getAttribute("href");
      if (original.target) proxy.target = original.target;
      if (original.rel) proxy.rel = original.rel;
    } else {
      proxy = document.createElement("button");
      proxy.type = "button";
      proxy.addEventListener("click", function () {
        closeMenu();
        window.setTimeout(function () { original.click(); }, 0);
      });
    }

    proxy.className = "tf-mobile-menu-item" + (isDangerAction(original) ? " tf-mobile-menu-danger" : "");
    proxy.textContent = label;
    proxy.setAttribute("data-tf-mobile-menu-proxy", "true");
    if (original.hasAttribute("aria-label")) proxy.setAttribute("aria-label", original.getAttribute("aria-label"));
    proxy.addEventListener("click", function () {
      if (proxy.tagName === "A") closeMenu();
    });
    return proxy;
  }

  function buildOverlay(actions, primary) {
    var existing = document.getElementById(OVERLAY_ID);
    if (existing) existing.remove();

    var overlay = document.createElement("div");
    overlay.id = OVERLAY_ID;
    overlay.setAttribute("aria-hidden", "true");
    overlay.innerHTML = [
      '<div class="tf-mobile-menu-sheet" role="dialog" aria-modal="true" aria-labelledby="tf-mobile-menu-title">',
      '  <div class="tf-mobile-menu-head">',
      '    <h2 class="tf-mobile-menu-title" id="tf-mobile-menu-title">Navegação</h2>',
      '    <button class="tf-mobile-menu-close" type="button" aria-label="Fechar menu">×</button>',
      '  </div>',
      '  <div class="tf-mobile-menu-list"></div>',
      '</div>'
    ].join("");

    var list = overlay.querySelector(".tf-mobile-menu-list");
    actions.forEach(function (action) {
      if (action === primary) return;
      list.appendChild(proxyAction(action));
    });

    overlay.querySelector(".tf-mobile-menu-close").addEventListener("click", closeMenu);
    overlay.addEventListener("click", function (event) {
      if (event.target === overlay) closeMenu();
    });
    document.body.appendChild(overlay);
  }

  function buildBar(source, actions, primary) {
    var existing = document.getElementById(BAR_ID);
    if (existing) existing.remove();

    var bar = document.createElement("nav");
    bar.id = BAR_ID;
    bar.setAttribute("aria-label", "Navegação principal no celular");

    if (primary && primary.tagName === "A" && primary.getAttribute("href")) {
      var primaryLink = document.createElement("a");
      primaryLink.className = "tf-mobile-nav-primary";
      primaryLink.href = primary.getAttribute("href");
      primaryLink.textContent = normalizeText(primary.textContent) || "Voltar";
      if (primary.target) primaryLink.target = primary.target;
      if (primary.rel) primaryLink.rel = primary.rel;
      bar.appendChild(primaryLink);
    } else {
      var spacer = document.createElement("span");
      spacer.className = "tf-mobile-nav-primary";
      spacer.textContent = "Navegação";
      bar.appendChild(spacer);
    }

    var toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "tf-mobile-nav-toggle";
    toggle.setAttribute("aria-controls", OVERLAY_ID);
    toggle.setAttribute("aria-expanded", "false");
    toggle.innerHTML = '<span class="tf-mobile-nav-toggle-icon" aria-hidden="true">☰</span><span>Menu</span>';
    toggle.addEventListener("click", openMenu);
    bar.appendChild(toggle);

    source.parentNode.insertBefore(bar, source);
  }

  function clearEnhancement() {
    if (currentSource) currentSource.classList.remove("tf-mobile-nav-source-active");
    currentSource = null;
    var bar = document.getElementById(BAR_ID);
    var overlay = document.getElementById(OVERLAY_ID);
    if (bar) bar.remove();
    if (overlay) overlay.remove();
    document.body.classList.remove("tf-mobile-menu-open");
  }

  function refresh() {
    if (!document.body) return;
    installStyles();

    var source = chooseSource();
    if (!source) {
      clearEnhancement();
      return;
    }

    var actions = directActions(source).filter(function (action) {
      return !action.hasAttribute("hidden") && action.getAttribute("aria-hidden") !== "true";
    });
    if (actions.length < 2) {
      clearEnhancement();
      return;
    }

    if (currentSource && currentSource !== source) currentSource.classList.remove("tf-mobile-nav-source-active");
    currentSource = source;
    source.classList.add("tf-mobile-nav-source-active");

    var primary = choosePrimary(actions);
    buildBar(source, actions, primary);
    buildOverlay(actions, primary);
  }

  function scheduleRefresh() {
    window.clearTimeout(refreshTimer);
    refreshTimer = window.setTimeout(refresh, 80);
  }

  function installObserver() {
    var observer = new MutationObserver(function (mutations) {
      var shouldRefresh = mutations.some(function (mutation) {
        if (mutation.type !== "childList") return false;
        return Array.from(mutation.addedNodes || []).concat(Array.from(mutation.removedNodes || [])).some(function (node) {
          if (!node || node.nodeType !== 1) return false;
          if (node.id === BAR_ID || node.id === OVERLAY_ID || node.closest && node.closest("#" + BAR_ID + ",#" + OVERLAY_ID)) return false;
          return true;
        });
      });
      if (shouldRefresh) scheduleRefresh();
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeMenu();
  });

  var media = window.matchMedia(MOBILE_QUERY);
  if (media.addEventListener) media.addEventListener("change", scheduleRefresh);
  else if (media.addListener) media.addListener(scheduleRefresh);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      refresh();
      installObserver();
    }, { once: true });
  } else {
    refresh();
    installObserver();
  }
})();
