(function () {
  "use strict";

  var BANNER_ID = "tf-tuition-payment-banner";
  var MODAL_ID = "tf-tuition-payment-modal";
  var STYLE_ID = "tf-tuition-payment-notice-styles";
  var PAYMENT_PATH = "/pagamento/";

  function sleep(milliseconds) {
    return new Promise(function (resolve) { window.setTimeout(resolve, milliseconds); });
  }

  async function waitForAuth() {
    for (var attempt = 0; attempt < 40; attempt += 1) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured && Auth.isConfigured()) return true;
      await sleep(250);
    }
    return false;
  }

  function formatCurrency(value) {
    var amount = Number(value);
    return Number.isFinite(amount)
      ? amount.toLocaleString("pt-BR", { style: "currency", currency: "BRL" })
      : "valor não informado";
  }

  function formatReferenceMonth(value) {
    var date = new Date(String(value || "") + "T12:00:00");
    if (Number.isNaN(date.getTime())) return "mensalidade";
    return date.toLocaleDateString("pt-BR", { month: "long", year: "numeric" });
  }

  function formatDate(value) {
    var date = new Date(String(value || "") + "T12:00:00");
    if (Number.isNaN(date.getTime())) return "data não informada";
    return date.toLocaleDateString("pt-BR");
  }

  function summarizeTuitions(tuitions) {
    var total = tuitions.reduce(function (sum, tuition) {
      return sum + (Number(tuition.amount_due) || 0);
    }, 0);
    var oldest = tuitions[0];
    var pendingAttempt = tuitions.some(function (tuition) {
      return ["pending", "authorized", "in_process", "in_mediation"].includes(tuition.attempt_status);
    });

    if (tuitions.length === 1) {
      return {
        banner: (pendingAttempt ? "Pagamento aguardando confirmação: " : "Mensalidade pendente: ")
          + formatReferenceMonth(oldest.reference_month) + " · " + formatCurrency(oldest.amount_due) + ".",
        title: pendingAttempt ? "Pagamento aguardando confirmação" : "Você possui uma mensalidade pendente",
        description: "A mensalidade de " + formatReferenceMonth(oldest.reference_month)
          + ", no valor de " + formatCurrency(oldest.amount_due)
          + ", está com vencimento em " + formatDate(oldest.due_date) + ".",
        total: total
      };
    }

    return {
      banner: tuitions.length + " mensalidades pendentes · total " + formatCurrency(total) + ".",
      title: "Você possui mensalidades pendentes",
      description: "Existem " + tuitions.length + " mensalidades em aberto, somando "
        + formatCurrency(total) + ". A cobrança mais antiga venceu ou vence em "
        + formatDate(oldest.due_date) + ".",
      total: total
    };
  }

  function installStyles() {
    if (document.getElementById(STYLE_ID)) return;
    var style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = [
      "#" + BANNER_ID + ", #" + BANNER_ID + " * , #" + MODAL_ID + ", #" + MODAL_ID + " * { box-sizing: border-box; }",
      "#" + BANNER_ID + " { position: sticky; top: 0; z-index: 45000; display: flex; align-items: center; justify-content: center; gap: 16px; width: 100%; min-height: 58px; padding: 10px 18px; border-bottom: 1px solid rgba(254,202,202,.42); color: #fff; background: linear-gradient(135deg,#991b1b,#dc2626); box-shadow: 0 10px 30px rgba(127,29,29,.28); font-family: Inter,system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; text-align: left; }",
      "#" + BANNER_ID + " strong { font-size: 14px; line-height: 1.45; }",
      "#" + BANNER_ID + " a { flex: 0 0 auto; display: inline-flex; align-items: center; justify-content: center; min-height: 38px; padding: 9px 15px; border: 1px solid rgba(255,255,255,.72); border-radius: 999px; color: #991b1b; background: #fff; font-size: 12px; font-weight: 900; letter-spacing: .03em; text-decoration: none; text-transform: uppercase; }",
      "#" + BANNER_ID + " a:hover { background: #fef2f2; transform: translateY(-1px); }",
      "#" + BANNER_ID + " a:focus-visible, #" + MODAL_ID + " button:focus-visible, #" + MODAL_ID + " a:focus-visible { outline: 3px solid #fde047; outline-offset: 3px; }",
      "#" + MODAL_ID + " { position: fixed; inset: 0; z-index: 50000; display: flex; align-items: center; justify-content: center; padding: 22px; background: rgba(2,6,23,.76); backdrop-filter: blur(8px); font-family: Inter,system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; }",
      "#" + MODAL_ID + "[hidden] { display: none; }",
      "#" + MODAL_ID + " .tf-tuition-modal__box { width: min(100%,500px); padding: 28px; border: 1px solid rgba(248,113,113,.45); border-radius: 22px; color: #e5e7eb; background: linear-gradient(145deg,#111827,#1e293b); box-shadow: 0 28px 80px rgba(2,6,23,.58); position: relative; }",
      "#" + MODAL_ID + " .tf-tuition-modal__icon { display: inline-flex; align-items: center; justify-content: center; width: 48px; height: 48px; margin-bottom: 16px; border-radius: 15px; color: #fff; background: #dc2626; font-size: 24px; font-weight: 900; }",
      "#" + MODAL_ID + " h2 { margin: 0 42px 10px 0; color: #fff; font-size: clamp(23px,5vw,30px); line-height: 1.15; }",
      "#" + MODAL_ID + " p { margin: 0; color: #cbd5e1; font-size: 15px; line-height: 1.65; }",
      "#" + MODAL_ID + " .tf-tuition-modal__note { margin-top: 14px; padding: 12px 14px; border-radius: 12px; color: #fecaca; background: rgba(220,38,38,.12); font-size: 13px; }",
      "#" + MODAL_ID + " .tf-tuition-modal__actions { display: flex; gap: 10px; margin-top: 22px; }",
      "#" + MODAL_ID + " .tf-tuition-modal__pay { flex: 1; display: inline-flex; align-items: center; justify-content: center; min-height: 47px; padding: 11px 17px; border-radius: 999px; color: #fff; background: linear-gradient(135deg,#dc2626,#991b1b); font-size: 13px; font-weight: 900; text-decoration: none; text-transform: uppercase; }",
      "#" + MODAL_ID + " .tf-tuition-modal__later { min-height: 47px; padding: 11px 17px; border: 1px solid rgba(148,163,184,.35); border-radius: 999px; color: #cbd5e1; background: rgba(255,255,255,.04); font-size: 13px; font-weight: 800; cursor: pointer; }",
      "#" + MODAL_ID + " .tf-tuition-modal__close { position: absolute; top: 18px; right: 18px; width: 38px; height: 38px; border: 1px solid rgba(148,163,184,.28); border-radius: 50%; color: #fff; background: rgba(255,255,255,.05); font-size: 23px; line-height: 1; cursor: pointer; }",
      "@media (max-width:620px) { #" + BANNER_ID + " { align-items: stretch; flex-direction: column; gap: 8px; padding: 11px 14px; } #" + BANNER_ID + " strong { text-align: center; } #" + BANNER_ID + " a { width: 100%; } #" + MODAL_ID + " .tf-tuition-modal__box { padding: 24px 20px; } #" + MODAL_ID + " .tf-tuition-modal__actions { flex-direction: column; } }",
      "@media print { #" + BANNER_ID + ", #" + MODAL_ID + " { display: none !important; } }"
    ].join("\n");
    document.head.appendChild(style);
  }

  function showBanner(summary) {
    if (document.getElementById(BANNER_ID)) return;
    var banner = document.createElement("aside");
    banner.id = BANNER_ID;
    banner.setAttribute("role", "alert");
    banner.setAttribute("aria-label", "Aviso de mensalidade pendente");
    banner.innerHTML = '<strong>' + summary.banner + '</strong><a href="' + PAYMENT_PATH + '">Pagar mensalidade</a>';
    document.body.insertBefore(banner, document.body.firstChild);
  }

  function closeModal() {
    var modal = document.getElementById(MODAL_ID);
    if (modal) modal.hidden = true;
  }

  function showModal(summary, session, oldestTuition) {
    if (window.location.pathname.replace(/\/index\.html$/, "/") === PAYMENT_PATH) return;
    if (document.getElementById(MODAL_ID)) return;

    var storageKey = "tf-tuition-payment-popup:" + session.user.id + ":" + oldestTuition.tuition_id;
    try {
      if (window.sessionStorage.getItem(storageKey) === "shown") return;
      window.sessionStorage.setItem(storageKey, "shown");
    } catch (error) {
      // O aviso continua funcionando mesmo quando o navegador bloqueia sessionStorage.
    }

    var modal = document.createElement("div");
    modal.id = MODAL_ID;
    modal.setAttribute("role", "dialog");
    modal.setAttribute("aria-modal", "true");
    modal.setAttribute("aria-labelledby", "tf-tuition-modal-title");
    modal.innerHTML = [
      '<div class="tf-tuition-modal__box">',
      '  <button class="tf-tuition-modal__close" type="button" aria-label="Fechar aviso">×</button>',
      '  <div class="tf-tuition-modal__icon" aria-hidden="true">!</div>',
      '  <h2 id="tf-tuition-modal-title">' + summary.title + '</h2>',
      '  <p>' + summary.description + '</p>',
      '  <p class="tf-tuition-modal__note">O pagamento pode ser feito com Pix ou cartão de crédito em ambiente protegido pelo Mercado Pago.</p>',
      '  <div class="tf-tuition-modal__actions">',
      '    <a class="tf-tuition-modal__pay" href="' + PAYMENT_PATH + '">Pagar agora</a>',
      '    <button class="tf-tuition-modal__later" type="button">Ver depois</button>',
      '  </div>',
      '</div>'
    ].join("");

    modal.querySelector(".tf-tuition-modal__close").addEventListener("click", closeModal);
    modal.querySelector(".tf-tuition-modal__later").addEventListener("click", closeModal);
    modal.addEventListener("click", function (event) {
      if (event.target === modal) closeModal();
    });
    document.addEventListener("keydown", function closeOnEscape(event) {
      if (event.key === "Escape") closeModal();
    });
    document.body.appendChild(modal);
    modal.querySelector(".tf-tuition-modal__pay").focus();
  }

  async function initializePaymentNotice() {
    if (!(await waitForAuth())) return;

    var session;
    try {
      session = await Auth.getSession();
    } catch (error) {
      return;
    }
    if (!session || !session.user) return;

    try {
      var response = await Auth.getClient().rpc("get_my_pending_tuitions");
      if (response.error) throw response.error;
      var tuitions = Array.isArray(response.data) ? response.data : [];
      var hasPaymentWaitingForConfirmation = tuitions.some(function (tuition) {
        return !!tuition.provider_payment_id
          && ["created", "pending", "authorized", "in_process", "in_mediation"].includes(tuition.attempt_status);
      });

      if (hasPaymentWaitingForConfirmation) {
        try {
          var reconciliation = await Auth.getClient().functions.invoke("reconcile-mercado-pago-payments", {
            body: {}
          });
          if (!reconciliation.error) {
            response = await Auth.getClient().rpc("get_my_pending_tuitions");
            if (response.error) throw response.error;
            tuitions = Array.isArray(response.data) ? response.data : [];
          }
        } catch (reconciliationError) {
          console.warn(
            "Não foi possível reconciliar o pagamento pendente:",
            reconciliationError && reconciliationError.message ? reconciliationError.message : reconciliationError
          );
        }
      }
      if (!tuitions.length) return;

      installStyles();
      var summary = summarizeTuitions(tuitions);
      showBanner(summary);
      showModal(summary, session, tuitions[0]);
    } catch (error) {
      console.warn("Não foi possível verificar mensalidades pendentes:", error && error.message ? error.message : error);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializePaymentNotice, { once: true });
  } else {
    initializePaymentNotice();
  }
})();
