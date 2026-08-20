(function () {
  "use strict";

  var EXPERIMENT_NAME = "cta_copy_v1";
  var VARIANT_KEY = "tf_cro_cta_copy_v1";

  if (window.gtag && window.gtag.__tfAttributionWrapped) return;

  window.dataLayer = window.dataLayer || [];
  var originalGtag = typeof window.gtag === "function" ? window.gtag : null;

  function currentPath() {
    return (window.location.pathname || "/").toLowerCase();
  }

  function isSalesPage() {
    return currentPath().indexOf("/curso-de-ingles-online") === 0;
  }

  function safeGet(key) {
    try { return window.localStorage.getItem(key); } catch (error) { return null; }
  }

  function safeSet(key, value) {
    try { window.localStorage.setItem(key, value); } catch (error) { /* Storage may be unavailable. */ }
  }

  function queryVariantOverride() {
    if (!isSalesPage()) return "";
    try {
      var value = new URLSearchParams(window.location.search || "").get("cro_variant");
      return value === "a" || value === "b" ? value : "";
    } catch (error) {
      return "";
    }
  }

  function getVariant() {
    var override = queryVariantOverride();
    if (override) return override;

    var stored = safeGet(VARIANT_KEY);
    if (stored === "a" || stored === "b") return stored;
    if (!isSalesPage()) return "";

    var assigned = Math.random() < 0.5 ? "a" : "b";
    safeSet(VARIANT_KEY, assigned);
    return assigned;
  }

  function attributionParams() {
    var variant = getVariant();
    return {
      cro_experiment: variant ? EXPERIMENT_NAME : "none",
      cro_variant: variant || "not_exposed"
    };
  }

  function forward() {
    if (originalGtag) return originalGtag.apply(window, arguments);
    window.dataLayer.push(arguments);
  }

  function wrappedGtag(command, eventName, params) {
    if (command === "event" && typeof eventName === "string") {
      var enriched = Object.assign({}, attributionParams(), params || {});
      if (isSalesPage()) enriched.site_area = "marketing";
      return forward("event", eventName, enriched);
    }
    return forward.apply(null, arguments);
  }

  wrappedGtag.__tfAttributionWrapped = true;
  window.gtag = wrappedGtag;
  window.TeacherCroAttribution = {
    experiment_name: EXPERIMENT_NAME,
    getVariant: getVariant,
    getParams: attributionParams
  };
})();
