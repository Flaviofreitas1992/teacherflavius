(function () {
  "use strict";

  var MEASUREMENT_ID = "G-BGMFE51RB6";
  var SCRIPT_ID = "teacher-flavius-google-tag";
  var FIRST_TOUCH_KEY = "tf_analytics_first_touch_v1";
  var LAST_TOUCH_KEY = "tf_analytics_last_touch_v1";
  var PURCHASES_KEY = "tf_analytics_purchases_v1";
  var formStates = new Map();
  var checkoutSeen = Object.create(null);
  var paymentContext = null;

  function safeJsonParse(value, fallback) {
    try { return JSON.parse(value); } catch (error) { return fallback; }
  }

  function safeStorageGet(storage, key) {
    try { return storage.getItem(key); } catch (error) { return null; }
  }

  function safeStorageSet(storage, key, value) {
    try { storage.setItem(key, value); } catch (error) { /* Storage can be unavailable. */ }
  }

  function cleanText(value, maxLength) {
    var text = String(value == null ? "" : value).replace(/\s+/g, " ").trim();
    return text.slice(0, maxLength || 100);
  }

  function currentPath() {
    return window.location.pathname || "/";
  }

  function classifyArea(path) {
    path = String(path || "/").toLowerCase();
    if (path === "/" || path === "/index.html" || path.indexOf("/quero-conhecer") === 0 || path.indexOf("/quero_conhecer") === 0 || path.indexOf("/landing-page") === 0) return "marketing";
    if (path.indexOf("/complete-cadastro") === 0 || path.indexOf("/cadastro") === 0 || path.indexOf("/login") === 0) return "enrollment";
    if (path.indexOf("/pagamento") === 0 || path.indexOf("/mensalidades") === 0) return "payment";
    if (path.indexOf("/professor") === 0 || path.indexOf("/perfil-dos-alunos") === 0 || path.indexOf("/editar-aluno") === 0 || path.indexOf("/relatorios") === 0 || path.indexOf("/radar-de-alunos") === 0 || path.indexOf("/turmas") === 0) return "admin";
    return "student_portal";
  }

  function referrerHost() {
    if (!document.referrer) return "";
    try { return new URL(document.referrer).hostname.toLowerCase(); } catch (error) { return ""; }
  }

  function acquisitionFromLocation() {
    var params = new URLSearchParams(window.location.search || "");
    var source = cleanText(params.get("utm_source"), 80);
    var medium = cleanText(params.get("utm_medium"), 80);
    var campaign = cleanText(params.get("utm_campaign"), 100);
    var content = cleanText(params.get("utm_content"), 100);
    var term = cleanText(params.get("utm_term"), 100);
    var refHost = referrerHost();

    if (!source) {
      if (refHost && refHost !== window.location.hostname.toLowerCase()) {
        source = refHost;
        medium = medium || "referral";
      } else {
        source = "direct";
        medium = medium || "none";
      }
    }

    return {
      source: source,
      medium: medium || "unknown",
      campaign: campaign || "not_set",
      content: content || "not_set",
      term: term || "not_set",
      landing_page: currentPath(),
      captured_at: new Date().toISOString()
    };
  }

  function getAcquisition() {
    var current = acquisitionFromLocation();
    var hasUtm = new URLSearchParams(window.location.search || "").has("utm_source");
    var first = safeJsonParse(safeStorageGet(window.localStorage, FIRST_TOUCH_KEY), null);
    if (!first) {
      first = current;
      safeStorageSet(window.localStorage, FIRST_TOUCH_KEY, JSON.stringify(first));
    }
    if (hasUtm || !safeStorageGet(window.sessionStorage, LAST_TOUCH_KEY)) {
      safeStorageSet(window.sessionStorage, LAST_TOUCH_KEY, JSON.stringify(current));
    }
    return {
      first: first,
      last: safeJsonParse(safeStorageGet(window.sessionStorage, LAST_TOUCH_KEY), current)
    };
  }

  var acquisition = getAcquisition();

  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function () { window.dataLayer.push(arguments); };
  window.gtag("js", new Date());
  window.gtag("config", MEASUREMENT_ID, {
    send_page_view: false,
    allow_google_signals: false
  });

  if (!document.getElementById(SCRIPT_ID)) {
    var tag = document.createElement("script");
    tag.id = SCRIPT_ID;
    tag.async = true;
    tag.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(MEASUREMENT_ID);
    document.head.appendChild(tag);
  }

  function baseParams() {
    return {
      site_area: classifyArea(currentPath()),
      page_path: currentPath(),
      first_touch_source: cleanText(acquisition.first && acquisition.first.source, 80),
      first_touch_medium: cleanText(acquisition.first && acquisition.first.medium, 80),
      first_touch_campaign: cleanText(acquisition.first && acquisition.first.campaign, 100),
      last_touch_source: cleanText(acquisition.last && acquisition.last.source, 80),
      last_touch_medium: cleanText(acquisition.last && acquisition.last.medium, 80),
      last_touch_campaign: cleanText(acquisition.last && acquisition.last.campaign, 100)
    };
  }

  function track(eventName, params) {
    var payload = Object.assign({}, baseParams(), params || {});
    window.gtag("event", eventName, payload);
  }

  track("page_view", {
    page_title: document.title || "Teacher Flávio",
    page_location: window.location.origin + currentPath()
  });

  function whatsappPosition(element) {
    if (!element) return "unknown";
    if (element.id === "teacher-flavius-whatsapp-float") return "floating_button";
    if (element.closest && element.closest(".hero")) return "hero";
    if (element.closest && element.closest(".final-cta")) return "final_cta";
    if (element.closest && element.closest("#teacher-flavius-site-footer")) return "footer";
    if (element.closest && element.closest(".payment-help")) return "payment_support";
    return "page_link";
  }

  function isWhatsappHref(href) {
    if (!href) return false;
    try {
      var url = new URL(href, window.location.href);
      return url.hostname === "wa.me" || url.hostname === "api.whatsapp.com" || /(^|\.)whatsapp\.com$/.test(url.hostname);
    } catch (error) {
      return false;
    }
  }

  document.addEventListener("click", function (event) {
    var target = event.target && event.target.closest ? event.target.closest("a[href],button") : null;
    if (!target) return;

    if (target.tagName === "A" && isWhatsappHref(target.getAttribute("href"))) {
      track("whatsapp_click", {
        link_position: whatsappPosition(target),
        link_text: cleanText(target.textContent || target.getAttribute("aria-label"), 100)
      });
    }

    if (target.id === "homeVideoTrigger") {
      track("video_start", {
        video_provider: "youtube",
        video_title: "Aula gratuita do Teacher Flávio"
      });
    }

    if (target.classList && target.classList.contains("tuition-card")) {
      window.setTimeout(trackBeginCheckoutIfReady, 0);
    }
  }, true);

  function formName(form) {
    return cleanText(form && (form.id || form.getAttribute("name") || "form"), 80) || "form";
  }

  function isLeadForm(form) {
    if (!form) return false;
    var name = formName(form).toLowerCase();
    var area = classifyArea(currentPath());
    return area === "enrollment" || /cadastro|matricula|lead|contact|profile/.test(name);
  }

  function ensureFormState(form) {
    if (!formStates.has(form)) {
      formStates.set(form, {
        started: false,
        submitted: false,
        completed: false,
        startedAt: 0,
        touched: new Set()
      });
    }
    return formStates.get(form);
  }

  function markFormInteraction(event) {
    var field = event.target;
    var form = field && field.form;
    if (!form || !isLeadForm(form)) return;
    var state = ensureFormState(form);
    if (!state.started) {
      state.started = true;
      state.startedAt = Date.now();
      track("lead_form_start", { form_name: formName(form) });
    }
    if (field.id || field.name) state.touched.add(cleanText(field.id || field.name, 80));
  }

  document.addEventListener("focusin", markFormInteraction, true);
  document.addEventListener("change", markFormInteraction, true);
  document.addEventListener("input", markFormInteraction, true);
  document.addEventListener("submit", function (event) {
    var form = event.target;
    if (!form || !isLeadForm(form)) return;
    var state = ensureFormState(form);
    state.submitted = true;
    track("lead_form_submit", {
      form_name: formName(form),
      fields_touched: state.touched.size,
      time_to_submit_seconds: state.startedAt ? Math.round((Date.now() - state.startedAt) / 1000) : 0
    });
  }, true);

  function markFormComplete(name) {
    document.querySelectorAll("form").forEach(function (form) {
      if (formName(form) !== name) return;
      var state = ensureFormState(form);
      state.completed = true;
      state.submitted = true;
    });
  }

  function markFormSubmitFailed(name) {
    document.querySelectorAll("form").forEach(function (form) {
      if (formName(form) !== name) return;
      ensureFormState(form).submitted = false;
    });
  }

  window.addEventListener("pagehide", function () {
    formStates.forEach(function (state, form) {
      if (!state.started || state.submitted || state.completed) return;
      track("lead_form_abandon", {
        form_name: formName(form),
        fields_touched: state.touched.size,
        time_on_form_seconds: state.startedAt ? Math.round((Date.now() - state.startedAt) / 1000) : 0,
        transport_type: "beacon"
      });
    });
  });

  function installAuthInstrumentation() {
    if (!window.Auth || typeof window.Auth.completeProfile !== "function" || window.Auth.completeProfile.__tfAnalyticsWrapped) return false;
    var original = window.Auth.completeProfile;
    var wrapped = async function () {
      try {
        var result = await original.apply(this, arguments);
        markFormComplete("completeProfileForm");
        track("sign_up", {
          method: "google",
          form_name: "completeProfileForm"
        });
        return result;
      } catch (error) {
        markFormSubmitFailed("completeProfileForm");
        track("lead_form_error", {
          form_name: "completeProfileForm",
          error_type: "profile_completion_failed"
        });
        throw error;
      }
    };
    wrapped.__tfAnalyticsWrapped = true;
    window.Auth.completeProfile = wrapped;
    return true;
  }

  function parseBrlAmount(text) {
    var normalized = String(text || "").replace(/[^0-9,.-]/g, "").replace(/\./g, "").replace(",", ".");
    var value = Number(normalized);
    return Number.isFinite(value) ? value : 0;
  }

  function paymentDomContext(tuitionId) {
    var selectedCard = document.querySelector(".tuition-card.selected");
    var amountNode = selectedCard && selectedCard.querySelector(".tuition-card__amount");
    return {
      tuition_id: cleanText(tuitionId || (selectedCard && selectedCard.getAttribute("data-tuition-id")), 80),
      value: parseBrlAmount(amountNode && amountNode.textContent),
      currency: "BRL"
    };
  }

  function checkoutItems(context) {
    return [{
      item_id: "monthly_tuition",
      item_name: "Mensalidade Teacher Flávio",
      item_variant: context.tuition_id || "tuition",
      price: context.value || 0,
      quantity: 1
    }];
  }

  function trackBeginCheckoutIfReady() {
    if (classifyArea(currentPath()) !== "payment") return false;
    var workspace = document.getElementById("paymentWorkspace");
    var selectedCard = document.querySelector(".tuition-card.selected");
    if (!workspace || workspace.hidden || !selectedCard) return false;
    var tuitionId = cleanText(selectedCard.getAttribute("data-tuition-id"), 80) || "selected";
    if (checkoutSeen[tuitionId]) return true;
    checkoutSeen[tuitionId] = true;
    var context = paymentDomContext(tuitionId);
    track("begin_checkout", {
      currency: context.currency,
      value: context.value,
      tuition_id: context.tuition_id,
      items: checkoutItems(context)
    });
    return true;
  }

  function purchaseAlreadyTracked(transactionId) {
    var ids = safeJsonParse(safeStorageGet(window.localStorage, PURCHASES_KEY), []);
    return Array.isArray(ids) && ids.indexOf(transactionId) !== -1;
  }

  function rememberPurchase(transactionId) {
    var ids = safeJsonParse(safeStorageGet(window.localStorage, PURCHASES_KEY), []);
    if (!Array.isArray(ids)) ids = [];
    if (ids.indexOf(transactionId) === -1) ids.push(transactionId);
    safeStorageSet(window.localStorage, PURCHASES_KEY, JSON.stringify(ids.slice(-50)));
  }

  function trackPurchase(paidTuitionId) {
    if (!paymentContext || !paymentContext.transaction_id) return;
    var transactionId = String(paymentContext.transaction_id);
    if (purchaseAlreadyTracked(transactionId)) return;
    var context = Object.assign({}, paymentContext, { tuition_id: cleanText(paidTuitionId || paymentContext.tuition_id, 80) });
    rememberPurchase(transactionId);
    track("purchase", {
      transaction_id: transactionId,
      currency: "BRL",
      value: context.value || 0,
      payment_type: context.payment_type || "unknown",
      tuition_id: context.tuition_id,
      items: checkoutItems(context)
    });
  }

  function installPaymentInstrumentation() {
    if (classifyArea(currentPath()) !== "payment") return true;

    if (typeof window.invokePaymentFunction === "function" && !window.invokePaymentFunction.__tfAnalyticsWrapped) {
      var originalInvoke = window.invokePaymentFunction;
      var wrappedInvoke = async function (payload) {
        var isPayment = payload && payload.action === "pay";
        var context = isPayment ? paymentDomContext(payload.tuition_id) : null;
        if (isPayment) {
          context.payment_type = cleanText(payload.selected_payment_method, 80) || "unknown";
          track("add_payment_info", {
            currency: "BRL",
            value: context.value,
            payment_type: context.payment_type,
            tuition_id: context.tuition_id,
            items: checkoutItems(context)
          });
        }
        try {
          var result = await originalInvoke.apply(this, arguments);
          if (isPayment && result && result.payment_id) {
            paymentContext = Object.assign({}, context, {
              transaction_id: String(result.payment_id)
            });
          }
          return result;
        } catch (error) {
          if (isPayment) {
            track("payment_error", {
              payment_type: context && context.payment_type || "unknown",
              tuition_id: context && context.tuition_id || "unknown",
              error_type: "payment_creation_failed"
            });
          }
          throw error;
        }
      };
      wrappedInvoke.__tfAnalyticsWrapped = true;
      window.invokePaymentFunction = wrappedInvoke;
    }

    if (typeof window.refreshAfterPayment === "function" && !window.refreshAfterPayment.__tfAnalyticsWrapped) {
      var originalRefresh = window.refreshAfterPayment;
      var wrappedRefresh = async function (paidTuitionId) {
        var completed = await originalRefresh.apply(this, arguments);
        if (completed === true) trackPurchase(paidTuitionId);
        return completed;
      };
      wrappedRefresh.__tfAnalyticsWrapped = true;
      window.refreshAfterPayment = wrappedRefresh;
    }

    trackBeginCheckoutIfReady();
    return typeof window.invokePaymentFunction === "function" && typeof window.refreshAfterPayment === "function";
  }

  function retryInstrumentation() {
    var tries = 0;
    var timer = window.setInterval(function () {
      tries += 1;
      var authReady = installAuthInstrumentation() || classifyArea(currentPath()) !== "enrollment";
      var paymentReady = installPaymentInstrumentation();
      trackBeginCheckoutIfReady();
      if ((authReady && paymentReady) || tries >= 60) window.clearInterval(timer);
    }, 250);
  }

  window.TeacherAnalytics = {
    measurementId: MEASUREMENT_ID,
    track: track,
    markFormComplete: markFormComplete,
    markFormSubmitFailed: markFormSubmitFailed,
    getAcquisition: function () { return acquisition; }
  };

  installAuthInstrumentation();
  installPaymentInstrumentation();
  retryInstrumentation();
})();
