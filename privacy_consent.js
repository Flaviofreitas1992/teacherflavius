(function () {
  "use strict";

  var STORAGE_KEY = "tf_privacy_consent_v1";
  var POLICY_VERSION = "2026-08-20";
  var CONSENT_VALIDITY_DAYS = 180;
  var GOOGLE_MEASUREMENT_ID = "G-11V3W5B6TG";
  var BANNER_ID = "tf-privacy-banner";
  var MODAL_ID = "tf-privacy-modal";
  var STYLE_ID = "tf-privacy-styles";
  var LEGACY_ANALYTICS_KEYS = [
    "tf_analytics_first_touch_v1",
    "tf_analytics_last_touch_v1",
    "tf_analytics_purchases_v1"
  ];

  function safeParse(value) {
    try { return JSON.parse(value); } catch (error) { return null; }
  }

  function safeStorageGet(key) {
    try { return window.localStorage.getItem(key); } catch (error) { return null; }
  }

  function safeStorageSet(key, value) {
    try { window.localStorage.setItem(key, value); return true; } catch (error) { return false; }
  }

  function safeStorageRemove(storage, key) {
    try { storage.removeItem(key); } catch (error) { /* Storage may be unavailable. */ }
  }

  function isoNow() { return new Date().toISOString(); }

  function expiresAt() {
    var date = new Date();
    date.setDate(date.getDate() + CONSENT_VALIDITY_DAYS);
    return date.toISOString();
  }

  function normalizeConsent(raw) {
    if (!raw || raw.policy_version !== POLICY_VERSION || !raw.updated_at || !raw.expires_at) return null;
    var expiry = Date.parse(raw.expires_at);
    if (!Number.isFinite(expiry) || expiry <= Date.now()) return null;
    return {
      policy_version: POLICY_VERSION,
      necessary: true,
      analytics: raw.analytics === true,
      updated_at: raw.updated_at,
      expires_at: raw.expires_at
    };
  }

  function getConsent() {
    return normalizeConsent(safeParse(safeStorageGet(STORAGE_KEY)));
  }

  function deleteCookie(name) {
    var host = window.location.hostname;
    var domainCandidates = ["", host, "." + host.replace(/^www\./, "")];
    domainCandidates.forEach(function (domain) {
      var value = name + "=; Max-Age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; SameSite=Lax";
      if (domain) value += "; domain=" + domain;
      document.cookie = value;
    });
  }

  function clearGoogleAnalyticsCookies() {
    var cookies = String(document.cookie || "").split(";");
    cookies.forEach(function (entry) {
      var name = entry.split("=")[0].trim();
      if (/^_ga(?:_|$)/.test(name) || /^_gid$/.test(name) || /^_gat(?:_|$)/.test(name)) deleteCookie(name);
    });
  }

  function clearAnalyticsLocalState() {
    LEGACY_ANALYTICS_KEYS.forEach(function (key) {
      safeStorageRemove(window.localStorage, key);
      safeStorageRemove(window.sessionStorage, key);
    });
  }

  function applyAnalyticsConsent(allowed) {
    window["ga-disable-" + GOOGLE_MEASUREMENT_ID] = allowed !== true;

    if (typeof window.gtag === "function") {
      window.gtag("consent", "update", {
        analytics_storage: allowed === true ? "granted" : "denied",
        ad_storage: "denied",
        ad_user_data: "denied",
        ad_personalization: "denied"
      });
    }

    if (!allowed) {
      clearGoogleAnalyticsCookies();
      clearAnalyticsLocalState();
    }
  }

  function setConsent(settings) {
    var consent = {
      policy_version: POLICY_VERSION,
      necessary: true,
      analytics: !!(settings && settings.analytics),
      updated_at: isoNow(),
      expires_at: expiresAt()
    };

    safeStorageSet(STORAGE_KEY, JSON.stringify(consent));
    applyAnalyticsConsent(consent.analytics);
    hideBanner();
    closePreferences();

    window.dispatchEvent(new CustomEvent("tf:privacy-consent-changed", {
      detail: { consent: consent }
    }));

    return consent;
  }

  function hasAnalyticsConsent() {
    var consent = getConsent();
    return !!(consent && consent.analytics);
  }

  function installStyles() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = [
      ".tf-privacy-banner,.tf-privacy-modal,.tf-privacy-banner *,.tf-privacy-modal *{box-sizing:border-box}",
      ".tf-privacy-banner{position:fixed;left:18px;right:18px;bottom:18px;z-index:30000;max-width:980px;margin:0 auto;padding:18px;border:1px solid rgba(148,163,184,.34);border-radius:18px;background:#0b1224;color:#e5e7eb;box-shadow:0 22px 70px rgba(0,0,0,.42);font-family:Inter,Arial,sans-serif}",
      ".tf-privacy-banner__title{margin:0 0 7px;color:#fff;font-size:17px;font-weight:800;line-height:1.25}",
      ".tf-privacy-banner__text{margin:0;color:#cbd5e1;font-size:13px;line-height:1.55}",
      ".tf-privacy-banner__text a,.tf-privacy-modal a{color:#c7d2fe;text-decoration:underline}",
      ".tf-privacy-banner__actions{display:flex;flex-wrap:wrap;gap:9px;margin-top:14px}",
      ".tf-privacy-button{min-height:42px;padding:10px 15px;border:1px solid rgba(255,255,255,.48);border-radius:10px;background:#111b34;color:#fff;font:700 13px/1.2 Inter,Arial,sans-serif;cursor:pointer}",
      ".tf-privacy-button:hover{background:#182645}.tf-privacy-button:focus-visible{outline:3px solid #facc15;outline-offset:2px}",
      ".tf-privacy-button--decision{background:#f8fafc;color:#0f172a;border-color:#f8fafc}.tf-privacy-button--decision:hover{background:#e2e8f0}",
      ".tf-privacy-modal[hidden]{display:none!important}",
      ".tf-privacy-modal{position:fixed;inset:0;z-index:31000;display:flex;align-items:center;justify-content:center;padding:20px;background:rgba(2,6,23,.75);font-family:Inter,Arial,sans-serif}",
      ".tf-privacy-modal__panel{width:min(620px,100%);max-height:min(760px,calc(100vh - 40px));overflow:auto;border:1px solid rgba(148,163,184,.3);border-radius:20px;background:#0b1224;color:#e5e7eb;box-shadow:0 26px 90px rgba(0,0,0,.5)}",
      ".tf-privacy-modal__header{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:22px 22px 12px}.tf-privacy-modal__header h2{margin:0;color:#fff;font-size:22px;line-height:1.2}",
      ".tf-privacy-close{width:40px;height:40px;border:1px solid rgba(255,255,255,.25);border-radius:10px;background:transparent;color:#fff;font-size:22px;cursor:pointer}",
      ".tf-privacy-modal__body{padding:0 22px 22px}.tf-privacy-modal__intro{margin:0 0 16px;color:#cbd5e1;font-size:14px;line-height:1.6}",
      ".tf-privacy-category{display:grid;grid-template-columns:1fr auto;gap:14px;padding:16px 0;border-top:1px solid rgba(148,163,184,.18)}",
      ".tf-privacy-category h3{margin:0 0 5px;color:#fff;font-size:15px}.tf-privacy-category p{margin:0;color:#aebbd0;font-size:13px;line-height:1.5}",
      ".tf-privacy-status{align-self:start;padding:5px 8px;border-radius:999px;background:rgba(34,197,94,.12);color:#86efac;font-size:11px;font-weight:800;text-transform:uppercase}",
      ".tf-privacy-switch{position:relative;display:inline-flex;align-items:center;align-self:start;width:48px;height:28px;margin-top:2px}",
      ".tf-privacy-switch input{position:absolute;opacity:0;width:1px;height:1px}",
      ".tf-privacy-slider{width:48px;height:28px;border:1px solid rgba(255,255,255,.35);border-radius:999px;background:#334155;cursor:pointer;transition:background 160ms ease}",
      ".tf-privacy-slider:before{content:'';display:block;width:20px;height:20px;margin:3px;border-radius:50%;background:#fff;transition:transform 160ms ease}",
      ".tf-privacy-switch input:checked + .tf-privacy-slider{background:#4f46e5}.tf-privacy-switch input:checked + .tf-privacy-slider:before{transform:translateX(20px)}",
      ".tf-privacy-switch input:focus-visible + .tf-privacy-slider{outline:3px solid #facc15;outline-offset:2px}",
      ".tf-privacy-modal__actions{display:flex;flex-wrap:wrap;gap:9px;padding-top:18px;border-top:1px solid rgba(148,163,184,.18)}",
      "body.tf-privacy-modal-open{overflow:hidden}",
      "@media(max-width:640px){.tf-privacy-banner{left:10px;right:10px;bottom:10px;padding:15px}.tf-privacy-banner__actions{display:grid;grid-template-columns:1fr}.tf-privacy-button{width:100%}.tf-privacy-modal{padding:10px}.tf-privacy-modal__panel{max-height:calc(100vh - 20px)}.tf-privacy-modal__actions{display:grid;grid-template-columns:1fr}}",
      "@media(prefers-reduced-motion:reduce){.tf-privacy-slider,.tf-privacy-slider:before{transition:none}}"
    ].join("");
    document.head.appendChild(style);
  }

  function buildBanner() {
    if (!document.body || document.getElementById(BANNER_ID)) return;
    var banner = document.createElement("section");
    banner.id = BANNER_ID;
    banner.className = "tf-privacy-banner";
    banner.setAttribute("role", "dialog");
    banner.setAttribute("aria-label", "Preferências de privacidade");
    banner.innerHTML = [
      '<h2 class="tf-privacy-banner__title">Sua privacidade no Teacher Flávio</h2>',
      '<p class="tf-privacy-banner__text">Usamos tecnologias necessárias para autenticação e funcionamento do portal. Com sua autorização, também usamos Google Analytics para medir o uso do site. Você pode aceitar ou recusar a medição sem perder acesso ao serviço. Consulte a <a href="/cookies/">Política de Cookies</a> e a <a href="/privacidade/">Política de Privacidade</a>.</p>',
      '<div class="tf-privacy-banner__actions">',
      '  <button class="tf-privacy-button tf-privacy-button--decision" type="button" data-tf-consent="reject">Recusar opcionais</button>',
      '  <button class="tf-privacy-button" type="button" data-tf-consent="preferences">Personalizar</button>',
      '  <button class="tf-privacy-button tf-privacy-button--decision" type="button" data-tf-consent="accept">Aceitar todos</button>',
      '</div>'
    ].join("");
    document.body.appendChild(banner);
  }

  function buildPreferences() {
    if (!document.body || document.getElementById(MODAL_ID)) return;
    var modal = document.createElement("div");
    modal.id = MODAL_ID;
    modal.className = "tf-privacy-modal";
    modal.hidden = true;
    modal.innerHTML = [
      '<div class="tf-privacy-modal__panel" role="dialog" aria-modal="true" aria-labelledby="tf-privacy-title">',
      '  <div class="tf-privacy-modal__header">',
      '    <h2 id="tf-privacy-title">Preferências de privacidade</h2>',
      '    <button class="tf-privacy-close" type="button" aria-label="Fechar preferências" data-tf-privacy-close>&times;</button>',
      '  </div>',
      '  <div class="tf-privacy-modal__body">',
      '    <p class="tf-privacy-modal__intro">Escolha quais tecnologias opcionais podem ser usadas. As necessárias permanecem ativas porque sustentam recursos como autenticação, segurança e sessão.</p>',
      '    <div class="tf-privacy-category">',
      '      <div><h3>Necessárias</h3><p>Permitem funções essenciais do portal, autenticação, segurança e preferências indispensáveis. Não podem ser desativadas por este painel.</p></div>',
      '      <span class="tf-privacy-status">Sempre ativas</span>',
      '    </div>',
      '    <div class="tf-privacy-category">',
      '      <div><h3>Analytics</h3><p>Google Analytics e dados de atribuição usados para entender visitas, navegação e conversões. O Google Analytics só é carregado após sua autorização.</p></div>',
      '      <label class="tf-privacy-switch"><input id="tf-analytics-consent" type="checkbox" aria-label="Permitir analytics"><span class="tf-privacy-slider" aria-hidden="true"></span></label>',
      '    </div>',
      '    <div class="tf-privacy-modal__actions">',
      '      <button class="tf-privacy-button tf-privacy-button--decision" type="button" data-tf-consent="reject">Recusar opcionais</button>',
      '      <button class="tf-privacy-button tf-privacy-button--decision" type="button" data-tf-consent="save">Salvar preferências</button>',
      '    </div>',
      '  </div>',
      '</div>'
    ].join("");
    document.body.appendChild(modal);
  }

  function hideBanner() {
    var banner = document.getElementById(BANNER_ID);
    if (banner) banner.hidden = true;
  }

  function showBannerIfNeeded() {
    var banner = document.getElementById(BANNER_ID);
    if (!banner) return;
    banner.hidden = !!getConsent();
  }

  function openPreferences() {
    buildPreferences();
    var modal = document.getElementById(MODAL_ID);
    if (!modal) return;
    var checkbox = document.getElementById("tf-analytics-consent");
    var consent = getConsent();
    if (checkbox) checkbox.checked = !!(consent && consent.analytics);
    modal.hidden = false;
    document.body.classList.add("tf-privacy-modal-open");
    var close = modal.querySelector("[data-tf-privacy-close]");
    if (close) close.focus();
  }

  function closePreferences() {
    var modal = document.getElementById(MODAL_ID);
    if (modal) modal.hidden = true;
    if (document.body) document.body.classList.remove("tf-privacy-modal-open");
  }

  function handleAction(action) {
    if (action === "accept") setConsent({ analytics: true });
    if (action === "reject") setConsent({ analytics: false });
    if (action === "preferences") openPreferences();
    if (action === "save") {
      var checkbox = document.getElementById("tf-analytics-consent");
      setConsent({ analytics: !!(checkbox && checkbox.checked) });
    }
  }

  function installInteractions() {
    document.addEventListener("click", function (event) {
      var actionTarget = event.target && event.target.closest ? event.target.closest("[data-tf-consent]") : null;
      if (actionTarget) {
        event.preventDefault();
        handleAction(actionTarget.getAttribute("data-tf-consent"));
        return;
      }

      var openTarget = event.target && event.target.closest ? event.target.closest("[data-tf-open-privacy]") : null;
      if (openTarget) {
        event.preventDefault();
        openPreferences();
        return;
      }

      if (event.target && event.target.matches && event.target.matches("[data-tf-privacy-close]")) closePreferences();
      if (event.target && event.target.id === MODAL_ID) closePreferences();
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") closePreferences();
    });
  }

  function mount() {
    installStyles();
    buildBanner();
    buildPreferences();
    showBannerIfNeeded();
  }

  var initialConsent = getConsent();
  applyAnalyticsConsent(!!(initialConsent && initialConsent.analytics));
  installInteractions();

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount, { once: true });
  else mount();

  window.TeacherFlaviusPrivacy = {
    policyVersion: POLICY_VERSION,
    getConsent: getConsent,
    hasAnalyticsConsent: hasAnalyticsConsent,
    setConsent: setConsent,
    openPreferences: openPreferences,
    revokeAnalytics: function () { return setConsent({ analytics: false }); }
  };
})();
