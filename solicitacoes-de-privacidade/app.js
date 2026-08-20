(function () {
  "use strict";

  var statusElement = document.getElementById("privacyAdminStatus");
  var rowsElement = document.getElementById("privacyRequestRows");
  var refreshButton = document.getElementById("refreshPrivacyRequests");
  var typeFilter = document.getElementById("privacyTypeFilter");
  var requests = [];

  var TYPE_LABELS = {
    account_deletion: "Encerramento da conta",
    data_access: "Acesso aos dados",
    correction: "Correção de dados",
    anonymization_blocking: "Anonimização / bloqueio",
    sharing_information: "Compartilhamentos"
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
    if (!value) return "—";
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return date.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
  }

  function statusLabel(value) {
    return { open: "Aberto", in_review: "Em análise", completed: "Concluído", cancelled: "Cancelado", rejected: "Rejeitado" }[value] || value;
  }

  function typeLabel(value) {
    return TYPE_LABELS[value] || value;
  }

  function setStatus(message, type) {
    statusElement.textContent = message;
    statusElement.style.borderColor = type === "error" ? "rgba(251,113,133,.5)" : "";
    statusElement.style.color = type === "error" ? "#fecdd3" : "";
  }

  function updateMetrics() {
    document.getElementById("metricOpen").textContent = requests.filter(function (item) { return item.status === "open"; }).length;
    document.getElementById("metricReview").textContent = requests.filter(function (item) { return item.status === "in_review"; }).length;
    document.getElementById("metricCompleted").textContent = requests.filter(function (item) { return item.status === "completed"; }).length;
  }

  function filteredRequests() {
    var selected = typeFilter && typeFilter.value || "";
    if (!selected) return requests;
    return requests.filter(function (item) { return item.request_type === selected; });
  }

  function requestContent(item) {
    var parts = [];
    if (item.request_details) parts.push('<div class="request-detail"><strong>Pedido:</strong> ' + escapeHtml(item.request_details) + '</div>');

    if (item.status === "completed" && item.request_type === "account_deletion") {
      var preserved = item.retention_summary && item.retention_summary.financial_records_preserved === true;
      parts.push('<div class="retention"><strong>Conclusão:</strong> ' + (preserved
        ? 'Dados operacionais eliminados; registros financeiros necessários preservados de forma pseudonimizada.'
        : 'Conta e dados associados eliminados sem necessidade de retenção financeira.') + '</div>');
    } else if (item.resolution_note) {
      parts.push('<div class="retention"><strong>Resposta:</strong> ' + escapeHtml(item.resolution_note) + '</div>');
    }

    if (!parts.length) parts.push('<span class="muted">Sem detalhes adicionais.</span>');
    return parts.join("");
  }

  function render() {
    updateMetrics();
    var visible = filteredRequests();
    if (!visible.length) {
      rowsElement.innerHTML = '<tr><td colspan="6" class="empty">Nenhuma solicitação encontrada para este filtro.</td></tr>';
      return;
    }

    rowsElement.innerHTML = visible.map(function (item) {
      var identity = item.subject_name || item.subject_email
        ? '<div class="subject"><strong>' + escapeHtml(item.subject_name || "Titular") + '</strong><small>' + escapeHtml(item.subject_email || "") + '</small></div>'
        : '<div class="subject"><strong>Identidade duplicada removida</strong><small>Referência: ' + escapeHtml(String(item.subject_user_id).slice(0, 8)) + '…</small></div>';

      var actions = [];
      if (item.status === "open") {
        actions.push('<button class="action review" type="button" data-action="review" data-id="' + escapeHtml(item.id) + '">INICIAR ANÁLISE</button>');
      }
      if (item.status === "open" || item.status === "in_review") {
        actions.push('<button class="action complete" type="button" data-action="complete" data-id="' + escapeHtml(item.id) + '">' +
          (item.request_type === "account_deletion" ? 'CONCLUIR ENCERRAMENTO' : 'REGISTRAR RESPOSTA') + '</button>');
      }

      return '<tr>' +
        '<td>' + escapeHtml(formatDate(item.requested_at)) + '</td>' +
        '<td><strong>' + escapeHtml(typeLabel(item.request_type)) + '</strong></td>' +
        '<td>' + identity + '</td>' +
        '<td>' + requestContent(item) + '</td>' +
        '<td><span class="badge ' + escapeHtml(item.status) + '">' + escapeHtml(statusLabel(item.status)) + '</span>' +
          (item.completed_at ? '<small class="completed-at">' + escapeHtml(formatDate(item.completed_at)) + '</small>' : '') + '</td>' +
        '<td><div class="actions">' + (actions.join("") || "—") + '</div></td>' +
      '</tr>';
    }).join("");
  }

  async function verifyTeacherAccess() {
    var user = await Auth.requireAuth({ skipProfileCheck: true });
    if (!user) return false;
    var response = await Auth.getClient().rpc("is_teacher_admin");
    if (response.error || response.data !== true) {
      window.location.replace("/area-do-estudante/");
      return false;
    }
    return true;
  }

  async function loadRequests() {
    setStatus("Carregando solicitações...");
    refreshButton.disabled = true;
    try {
      var response = await Auth.getClient()
        .from("data_subject_requests")
        .select("id,subject_user_id,subject_name,subject_email,request_type,request_details,status,requested_at,reviewed_at,completed_at,resolution_note,retention_summary")
        .order("requested_at", { ascending: false })
        .limit(300);
      if (response.error) throw response.error;
      requests = response.data || [];
      render();
      setStatus("Fila atualizada. Pedidos não destrutivos exigem uma resposta registrada; encerramentos continuam sujeitos ao fluxo de exclusão segura.");
    } catch (error) {
      setStatus(error.message || "Não foi possível carregar as solicitações.", "error");
    } finally {
      refreshButton.disabled = false;
    }
  }

  async function markReview(id, button) {
    var request = requests.find(function (item) { return item.id === id; });
    if (!request) return;
    button.disabled = true;
    try {
      var rpcName = request.request_type === "account_deletion"
        ? "mark_account_deletion_in_review"
        : "mark_data_subject_request_in_review";
      var response = await Auth.getClient().rpc(rpcName, { p_request_id: id });
      if (response.error) throw response.error;
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível iniciar a análise.", "error");
      button.disabled = false;
    }
  }

  async function completeDeletion(id, button, request) {
    var subject = request && (request.subject_name || request.subject_email) || "este aluno";
    var confirmed = window.confirm(
      "Concluir o encerramento da conta de " + subject + "?\n\nEsta ação remove a autenticação e os dados operacionais. Se houver histórico financeiro necessário, ele será preservado apenas com identificador pseudônimo. A ação sobre os dados eliminados não pode ser desfeita."
    );
    if (!confirmed) return;

    button.disabled = true;
    button.textContent = "PROCESSANDO...";
    try {
      var response = await Auth.getClient().rpc("complete_account_deletion_request", {
        p_request_id: id,
        p_resolution_note: "Conta encerrada após análise de privacidade e aplicação da retenção seletiva."
      });
      if (response.error) throw response.error;
      var closure = response.data && response.data.closure || {};
      window.alert(closure.financial_records_preserved
        ? "Pedido concluído. Os dados operacionais foram removidos e o histórico financeiro necessário permaneceu pseudonimizado."
        : "Pedido concluído. A conta e os dados associados foram eliminados sem necessidade de retenção financeira.");
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível concluir o pedido.", "error");
      button.disabled = false;
      button.textContent = "CONCLUIR ENCERRAMENTO";
    }
  }

  async function completeNonDestructive(id, button, request) {
    var promptText = "Registre a resposta que ficará disponível ao titular no portal.\n\nTipo: " + typeLabel(request.request_type);
    if (request.request_details) promptText += "\nPedido: " + request.request_details;
    var resolution = window.prompt(promptText, "");
    if (resolution === null) return;
    resolution = String(resolution || "").trim();
    if (!resolution) {
      window.alert("A resposta não pode ficar em branco.");
      return;
    }

    button.disabled = true;
    button.textContent = "SALVANDO...";
    try {
      var response = await Auth.getClient().rpc("complete_data_subject_request", {
        p_request_id: id,
        p_resolution_note: resolution
      });
      if (response.error) throw response.error;
      window.alert("Resposta registrada e solicitação concluída.");
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível registrar a resposta.", "error");
      button.disabled = false;
      button.textContent = "REGISTRAR RESPOSTA";
    }
  }

  async function completeRequest(id, button) {
    var request = requests.find(function (item) { return item.id === id; });
    if (!request) return;
    if (request.request_type === "account_deletion") return completeDeletion(id, button, request);
    return completeNonDestructive(id, button, request);
  }

  rowsElement.addEventListener("click", function (event) {
    var button = event.target.closest("button[data-action]");
    if (!button) return;
    var id = button.getAttribute("data-id");
    if (button.dataset.action === "review") markReview(id, button);
    if (button.dataset.action === "complete") completeRequest(id, button);
  });

  refreshButton.addEventListener("click", loadRequests);
  if (typeFilter) typeFilter.addEventListener("change", render);

  (async function init() {
    try {
      if (!await verifyTeacherAccess()) return;
      await loadRequests();
    } catch (error) {
      setStatus(error.message || "Não foi possível verificar o acesso de professor.", "error");
    }
  })();
})();
