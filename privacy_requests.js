(function () {
  "use strict";

  var statusElement;
  var requestButton;
  var cancelButton;
  var downloadButton;
  var formalTypeSelect;
  var formalDetails;
  var formalSubmitButton;
  var formalStatus;
  var historyElement;
  var activeDeletionRequest = null;
  var allRequests = [];

  var TYPE_LABELS = {
    account_deletion: "Encerramento da conta",
    data_access: "Acesso aos dados",
    correction: "Correção de dados",
    anonymization_blocking: "Anonimização ou bloqueio",
    sharing_information: "Informações sobre compartilhamentos"
  };

  var STATUS_LABELS = {
    open: "Aberto",
    in_review: "Em análise",
    completed: "Concluído",
    cancelled: "Cancelado",
    rejected: "Rejeitado"
  };

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatDate(value) {
    if (!value) return "";
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    return date.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
  }

  function setStatus(message, type) {
    if (!statusElement) return;
    statusElement.className = "privacy-request-status" + (type ? " " + type : "");
    statusElement.textContent = message || "";
  }

  function setFormalStatus(message, type) {
    if (!formalStatus) return;
    formalStatus.textContent = message || "";
    formalStatus.className = "privacy-form-status" + (type ? " " + type : "");
  }

  function injectStyles() {
    if (document.getElementById("privacyRightsCenterStyles")) return;
    var style = document.createElement("style");
    style.id = "privacyRightsCenterStyles";
    style.textContent = [
      ".privacy-rights-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin:18px 0}",
      ".privacy-right-card{border:1px solid rgba(129,140,248,.25);background:rgba(129,140,248,.06);border-radius:14px;padding:15px}",
      ".privacy-right-card h3{font-size:16px;margin:0 0 7px;color:#f1f5f9}",
      ".privacy-right-card p{font-size:13px;margin:0 0 12px}",
      ".privacy-secondary{width:100%;color:#c4b5fd;font-weight:bold}",
      ".privacy-form{margin:18px 0;padding:16px;border:1px solid rgba(255,255,255,.1);border-radius:14px;background:rgba(255,255,255,.025)}",
      ".privacy-form label{margin-top:10px}",
      ".privacy-form select,.privacy-form textarea{width:100%;background:rgba(255,255,255,.06);border:1.5px solid rgba(255,255,255,.12);border-radius:12px;padding:12px 13px;color:#f1f5f9;font:14px Georgia,serif}",
      ".privacy-form select option{color:#111827;background:#fff}",
      ".privacy-form textarea{min-height:110px;resize:vertical;margin-bottom:10px}",
      ".privacy-form-help{font-size:12px;color:#94a3b8;margin:7px 0 12px}",
      ".privacy-form-status{min-height:18px;font-size:12px;color:#94a3b8;margin-top:8px}",
      ".privacy-form-status.success{color:#a7f3d0}.privacy-form-status.error{color:#fecaca}",
      ".privacy-history{margin:18px 0}",
      ".privacy-history h3{font-size:16px;margin:0 0 10px}",
      ".privacy-history-list{display:grid;gap:9px}",
      ".privacy-history-item{border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:12px;background:rgba(255,255,255,.025)}",
      ".privacy-history-head{display:flex;justify-content:space-between;gap:10px;align-items:flex-start}",
      ".privacy-history-head strong{font-size:13px}.privacy-history-head span{font-size:12px;color:#cbd5e1}",
      ".privacy-history-item p{font-size:12px;margin:7px 0 0;color:#94a3b8;white-space:pre-wrap}",
      ".privacy-history-response{color:#a7f3d0!important}",
      ".privacy-history-cancel{margin-top:9px;padding:7px 10px;font-size:12px;color:#cbd5e1}",
      "@media(max-width:650px){.privacy-rights-grid{grid-template-columns:1fr}.privacy-history-head{display:block}.privacy-history-head span{display:block;margin-top:4px}}"
    ].join("");
    document.head.appendChild(style);
  }

  function ensureRightsCenterUi() {
    var title = document.getElementById("privacyTitle");
    var section = title && title.closest("section");
    if (!section || document.getElementById("privacyRightsCenter")) return;

    injectStyles();

    var links = section.querySelector(".privacy-links");
    var wrapper = document.createElement("div");
    wrapper.id = "privacyRightsCenter";
    wrapper.innerHTML = [
      '<div class="privacy-rights-grid">',
        '<div class="privacy-right-card">',
          '<h3>Cópia dos meus dados</h3>',
          '<p>Gere no seu próprio navegador uma cópia em JSON dos principais dados diretamente associados à sua conta. O arquivo não é armazenado como uma segunda cópia no portal.</p>',
          '<button id="downloadMyDataButton" class="privacy-secondary" type="button">BAIXAR CÓPIA DOS MEUS DADOS</button>',
        '</div>',
        '<div class="privacy-right-card">',
          '<h3>Correções simples</h3>',
          '<p>Nome, CPF, WhatsApp, chave PIX e disponibilidade podem ser corrigidos diretamente no formulário acima. Para outros registros, use a solicitação formal abaixo.</p>',
          '<a class="btn privacy-secondary" href="#profileForm">IR PARA MEUS DADOS</a>',
        '</div>',
      '</div>',
      '<div class="privacy-form" aria-labelledby="formalPrivacyRequestTitle">',
        '<h3 id="formalPrivacyRequestTitle">Solicitação formal de privacidade</h3>',
        '<label for="privacyFormalType">O que você deseja solicitar?</label>',
        '<select id="privacyFormalType">',
          '<option value="data_access">Acesso adicional ou esclarecimento sobre meus dados</option>',
          '<option value="correction">Correção de dado que não consigo alterar acima</option>',
          '<option value="anonymization_blocking">Anonimização ou bloqueio de dado</option>',
          '<option value="sharing_information">Informações sobre compartilhamento de dados</option>',
        '</select>',
        '<label for="privacyFormalDetails">Detalhes</label>',
        '<textarea id="privacyFormalDetails" maxlength="4000" placeholder="Descreva objetivamente o que você precisa. Não envie senhas nem dados de cartão."></textarea>',
        '<p id="privacyFormalHelp" class="privacy-form-help">Para acesso adicional, você pode indicar quais informações deseja esclarecer. Se precisar apenas da cópia automática, use o botão acima.</p>',
        '<button id="submitPrivacyFormalRequest" type="button">ENVIAR SOLICITAÇÃO</button>',
        '<div id="privacyFormalStatus" class="privacy-form-status" role="status" aria-live="polite"></div>',
      '</div>',
      '<div class="privacy-history">',
        '<h3>Minhas solicitações</h3>',
        '<div id="privacyRequestHistory" class="privacy-history-list"><p>Carregando histórico...</p></div>',
      '</div>'
    ].join("");

    if (links && links.nextSibling) section.insertBefore(wrapper, links.nextSibling);
    else section.insertBefore(wrapper, statusElement || null);

    downloadButton = document.getElementById("downloadMyDataButton");
    formalTypeSelect = document.getElementById("privacyFormalType");
    formalDetails = document.getElementById("privacyFormalDetails");
    formalSubmitButton = document.getElementById("submitPrivacyFormalRequest");
    formalStatus = document.getElementById("privacyFormalStatus");
    historyElement = document.getElementById("privacyRequestHistory");
  }

  function renderDeletionRequest(request) {
    activeDeletionRequest = request && ["open", "in_review"].includes(request.status) ? request : null;

    if (!request) {
      setStatus("Nenhum pedido de encerramento está ativo.");
      requestButton.hidden = false;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "open") {
      setStatus("Pedido de encerramento registrado em " + formatDate(request.requested_at) + ". Ele ainda pode ser cancelado enquanto não entrar em análise.", "warning");
      requestButton.hidden = true;
      cancelButton.hidden = false;
      return;
    }

    if (request.status === "in_review") {
      setStatus("Seu pedido de encerramento está em análise. A conta será encerrada após a verificação dos dados que podem ser eliminados e dos registros que precisam ser conservados.", "warning");
      requestButton.hidden = true;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "completed") {
      setStatus("O último pedido de encerramento foi concluído em " + formatDate(request.completed_at) + ".", "success");
      requestButton.hidden = true;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "cancelled") {
      setStatus("O último pedido de encerramento foi cancelado. Você pode fazer uma nova solicitação se necessário.");
      requestButton.hidden = false;
      cancelButton.hidden = true;
      return;
    }

    setStatus("O último pedido de encerramento foi finalizado sem exclusão. Consulte o histórico ou entre em contato se precisar de esclarecimentos.");
    requestButton.hidden = false;
    cancelButton.hidden = true;
  }

  function renderHistory() {
    if (!historyElement) return;
    var requests = allRequests.filter(function (item) { return item.request_type !== "account_deletion"; });

    if (!requests.length) {
      historyElement.innerHTML = '<p>Nenhuma solicitação formal registrada.</p>';
      return;
    }

    historyElement.innerHTML = requests.map(function (item) {
      var statusText = STATUS_LABELS[item.status] || item.status;
      var details = item.request_details ? '<p><b>Pedido:</b> ' + escapeHtml(item.request_details) + '</p>' : '';
      var response = item.resolution_note && item.status !== "cancelled"
        ? '<p class="privacy-history-response"><b>Resposta:</b> ' + escapeHtml(item.resolution_note) + '</p>'
        : '';
      var cancel = item.status === "open"
        ? '<button type="button" class="privacy-history-cancel" data-cancel-privacy-request="' + escapeHtml(item.id) + '">CANCELAR SOLICITAÇÃO</button>'
        : '';

      return '<div class="privacy-history-item">' +
        '<div class="privacy-history-head"><strong>' + escapeHtml(TYPE_LABELS[item.request_type] || item.request_type) + '</strong><span>' + escapeHtml(statusText) + ' · ' + escapeHtml(formatDate(item.requested_at)) + '</span></div>' +
        details + response + cancel +
      '</div>';
    }).join("");
  }

  async function loadRequests() {
    var response = await Auth.getClient()
      .from("data_subject_requests")
      .select("id,request_type,request_details,status,requested_at,reviewed_at,completed_at,resolution_note,retention_summary")
      .order("requested_at", { ascending: false })
      .limit(50);

    if (response.error) throw response.error;
    allRequests = response.data || [];
    var deletion = allRequests.find(function (item) { return item.request_type === "account_deletion"; }) || null;
    renderDeletionRequest(deletion);
    renderHistory();
  }

  async function downloadMyData() {
    if (!downloadButton) return;
    downloadButton.disabled = true;
    downloadButton.textContent = "GERANDO CÓPIA...";
    setFormalStatus("Gerando a cópia diretamente da sua conta...");

    try {
      var response = await Auth.getClient().rpc("get_my_data_export");
      if (response.error) throw response.error;

      var data = response.data || {};
      var content = JSON.stringify(data, null, 2);
      var blob = new Blob([content], { type: "application/json;charset=utf-8" });
      var url = URL.createObjectURL(blob);
      var anchor = document.createElement("a");
      var today = new Date().toISOString().slice(0, 10);
      anchor.href = url;
      anchor.download = "teacherflavius-meus-dados-" + today + ".json";
      document.body.appendChild(anchor);
      anchor.click();
      anchor.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
      setFormalStatus("Cópia gerada. O arquivo foi criado no seu navegador e não foi armazenado como uma nova cópia no portal.", "success");
    } catch (error) {
      setFormalStatus(error.message || "Não foi possível gerar a cópia dos seus dados.", "error");
    } finally {
      downloadButton.disabled = false;
      downloadButton.textContent = "BAIXAR CÓPIA DOS MEUS DADOS";
    }
  }

  function updateFormalHelp() {
    if (!formalTypeSelect) return;
    var help = document.getElementById("privacyFormalHelp");
    var value = formalTypeSelect.value;
    var messages = {
      data_access: "Para acesso adicional, indique quais informações deseja esclarecer. Se precisar apenas da cópia automática, use o botão acima.",
      correction: "Informe qual dado está incorreto, onde ele aparece e qual é a informação correta. Para nome, CPF, WhatsApp, PIX e disponibilidade, prefira o formulário de perfil acima.",
      anonymization_blocking: "Indique precisamente qual dado você considera desnecessário, excessivo ou inadequado e o tratamento que está solicitando.",
      sharing_information: "Se quiser, indique o fornecedor, integração ou categoria de compartilhamento sobre a qual deseja informações."
    };
    if (help) help.textContent = messages[value] || "Descreva objetivamente sua solicitação.";
  }

  async function submitFormalRequest() {
    if (!formalTypeSelect || !formalSubmitButton) return;
    var type = formalTypeSelect.value;
    var details = String(formalDetails && formalDetails.value || "").trim();

    if ((type === "correction" || type === "anonymization_blocking") && !details) {
      setFormalStatus("Descreva quais dados precisam ser corrigidos, anonimizados ou bloqueados.", "error");
      if (formalDetails) formalDetails.focus();
      return;
    }

    formalSubmitButton.disabled = true;
    formalSubmitButton.textContent = "ENVIANDO...";
    setFormalStatus("Registrando a solicitação...");

    try {
      var response = await Auth.getClient().rpc("create_data_subject_request", {
        p_request_type: type,
        p_request_details: details || null
      });
      if (response.error) throw response.error;
      if (formalDetails) formalDetails.value = "";
      setFormalStatus(response.data && response.data.already_existed
        ? "Já existe uma solicitação deste tipo aberta ou em análise."
        : "Solicitação registrada com sucesso.", "success");
      await loadRequests();
    } catch (error) {
      setFormalStatus(error.message || "Não foi possível registrar a solicitação.", "error");
    } finally {
      formalSubmitButton.disabled = false;
      formalSubmitButton.textContent = "ENVIAR SOLICITAÇÃO";
    }
  }

  async function cancelFormalRequest(id, button) {
    if (!window.confirm("Cancelar esta solicitação de privacidade?")) return;
    button.disabled = true;
    try {
      var response = await Auth.getClient().rpc("cancel_my_data_subject_request", { p_request_id: id });
      if (response.error) throw response.error;
      setFormalStatus("Solicitação cancelada.", "success");
      await loadRequests();
    } catch (error) {
      setFormalStatus(error.message || "Não foi possível cancelar a solicitação.", "error");
      button.disabled = false;
    }
  }

  async function createDeletionRequest() {
    var confirmed = window.confirm(
      "Deseja solicitar o encerramento da sua conta?\n\nO pedido não apaga tudo imediatamente. O professor fará a análise e eliminará ou anonimizará os dados que não precisem ser mantidos. Registros financeiros necessários para obrigações legais ou exercício de direitos poderão ser conservados de forma restrita."
    );
    if (!confirmed) return;

    requestButton.disabled = true;
    requestButton.textContent = "REGISTRANDO PEDIDO...";
    setStatus("Registrando sua solicitação...");

    try {
      var response = await Auth.getClient().rpc("request_account_deletion");
      if (response.error) throw response.error;
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível registrar o pedido.", "error");
    } finally {
      requestButton.disabled = false;
      requestButton.textContent = "SOLICITAR ENCERRAMENTO DA CONTA";
    }
  }

  async function cancelDeletionRequest() {
    if (!activeDeletionRequest || activeDeletionRequest.status !== "open") return;
    if (!window.confirm("Cancelar este pedido de encerramento da conta?")) return;

    cancelButton.disabled = true;
    try {
      var response = await Auth.getClient().rpc("cancel_my_account_deletion_request", { p_request_id: activeDeletionRequest.id });
      if (response.error) throw response.error;
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível cancelar o pedido.", "error");
    } finally {
      cancelButton.disabled = false;
    }
  }

  async function init() {
    statusElement = document.getElementById("privacyRequestStatus");
    requestButton = document.getElementById("requestAccountDeletionButton");
    cancelButton = document.getElementById("cancelAccountDeletionButton");
    if (!statusElement || !requestButton || !cancelButton || !window.Auth) return;

    ensureRightsCenterUi();

    requestButton.addEventListener("click", createDeletionRequest);
    cancelButton.addEventListener("click", cancelDeletionRequest);
    if (downloadButton) downloadButton.addEventListener("click", downloadMyData);
    if (formalSubmitButton) formalSubmitButton.addEventListener("click", submitFormalRequest);
    if (formalTypeSelect) formalTypeSelect.addEventListener("change", updateFormalHelp);
    if (historyElement) historyElement.addEventListener("click", function (event) {
      var button = event.target.closest("button[data-cancel-privacy-request]");
      if (!button) return;
      cancelFormalRequest(button.getAttribute("data-cancel-privacy-request"), button);
    });

    updateFormalHelp();

    try {
      var user = await Auth.requireAuth();
      if (!user) return;
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível consultar suas solicitações de privacidade.", "error");
      setFormalStatus(error.message || "Não foi possível carregar a central de privacidade.", "error");
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init, { once: true });
  else init();
})();
