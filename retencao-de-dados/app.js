(function () {
  "use strict";

  var statusElement = document.getElementById("retentionStatus");
  var rowsElement = document.getElementById("retentionRows");
  var processorStatusElement = document.getElementById("processorStatus");
  var processorRowsElement = document.getElementById("processorRows");
  var refreshButton = document.getElementById("refreshRetention");
  var runButton = document.getElementById("runRetentionNow");
  var dashboard = null;
  var processorDashboard = null;

  var datasetLabels = {
    student_access_logs: "Acessos dos alunos",
    app_error_events: "Erros da aplicação",
    csp_violation_reports: "Violações CSP",
    exercise_sync_events: "Eventos de sincronização",
    data_subject_requests: "Solicitações LGPD",
    financial_records: "Registros financeiros",
    core_student_records: "Dados acadêmicos/cadastrais",
    legacy_backup_snapshots: "Snapshots legados"
  };

  var categoryLabels = {
    operational: "Operacional",
    security_operations: "Segurança / diagnóstico",
    privacy_accountability: "Prestação de contas LGPD",
    legal_financial: "Financeiro / legal",
    service: "Prestação do serviço",
    backup: "Backup"
  };

  var processorStatusLabels = {
    verified: "Verificado",
    pending: "Pendente",
    action_required: "Ação necessária"
  };

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatDate(value, withTime) {
    if (!value) return "—";
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    if (withTime) return date.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
    return date.toLocaleDateString("pt-BR");
  }

  function safeExternalUrl(value) {
    try {
      var url = new URL(String(value || ""));
      return url.protocol === "https:" ? url.href : null;
    } catch (error) {
      return null;
    }
  }

  function setStatus(message, type) {
    statusElement.textContent = message || "";
    statusElement.style.borderColor = type === "error" ? "rgba(251,113,133,.5)" : "";
    statusElement.style.color = type === "error" ? "#fecdd3" : "";
  }

  function setProcessorStatus(message, type) {
    processorStatusElement.textContent = message || "";
    processorStatusElement.style.borderColor = type === "error" ? "rgba(251,113,133,.5)" : "";
    processorStatusElement.style.color = type === "error" ? "#fecdd3" : "";
  }

  function sumEligible(policies) {
    return (policies || []).reduce(function (sum, item) {
      return sum + (typeof item.eligible_now === "number" ? item.eligible_now : 0);
    }, 0);
  }

  function renderMetrics() {
    var policies = dashboard && dashboard.policies || [];
    var automaticCount = policies.filter(function (item) { return item.automatic_purge && item.enabled; }).length;
    document.getElementById("metricAutomatic").textContent = automaticCount;
    document.getElementById("metricEligible").textContent = sumEligible(policies).toLocaleString("pt-BR");

    var latestRun = dashboard && dashboard.latest_run;
    var runText = latestRun ? ({ completed: "Concluída", failed: "Falhou", skipped: "Ignorada", running: "Em andamento" }[latestRun.status] || latestRun.status) : "Sem execução";
    document.getElementById("metricLastRun").textContent = runText;

    var cronJob = dashboard && dashboard.cron_job;
    document.getElementById("metricCron").textContent = cronJob && cronJob.active ? "Ativo" : "Inativo";
  }

  function renderRows() {
    var policies = dashboard && dashboard.policies || [];
    if (!policies.length) {
      rowsElement.innerHTML = '<tr><td colspan="7" class="empty">Nenhuma política de retenção configurada.</td></tr>';
      return;
    }

    rowsElement.innerHTML = policies.map(function (item) {
      var automatic = item.automatic_purge && item.enabled;
      var rule = automatic
        ? '<span class="badge auto">Automático · ' + escapeHtml(item.retention_days) + ' dias</span>'
        : '<span class="badge manual">Revisão manual</span>';
      var records = item.record_count == null ? "—" : Number(item.record_count).toLocaleString("pt-BR");
      var eligible = item.eligible_now == null ? "—" : Number(item.eligible_now).toLocaleString("pt-BR");

      return '<tr>' +
        '<td><strong>' + escapeHtml(datasetLabels[item.dataset] || item.dataset) + '</strong></td>' +
        '<td>' + escapeHtml(categoryLabels[item.category] || item.category) + '</td>' +
        '<td>' + rule + '</td>' +
        '<td class="number">' + escapeHtml(records) + '</td>' +
        '<td class="number">' + escapeHtml(eligible) + '</td>' +
        '<td>' + escapeHtml(formatDate(item.next_review_at, false)) + '</td>' +
        '<td class="reason">' + escapeHtml(item.rationale || "—") + '</td>' +
      '</tr>';
    }).join("");
  }

  function renderStatus() {
    var latestRun = dashboard && dashboard.latest_run;
    var cronJob = dashboard && dashboard.cron_job;
    if (!latestRun) {
      setStatus("Políticas carregadas. Ainda não há execução registrada.");
      return;
    }

    var deleted = latestRun.deleted_counts || {};
    var deletedTotal = Object.keys(deleted).reduce(function (sum, key) { return sum + Number(deleted[key] || 0); }, 0);
    var cronText = cronJob && cronJob.active ? " O cron diário está ativo às 02:35 no horário de Brasília." : " O cron diário não está ativo.";

    if (latestRun.status === "failed") {
      setStatus("A última manutenção falhou em " + formatDate(latestRun.completed_at || latestRun.started_at, true) + ": " + (latestRun.error_message || "erro não informado") + "." + cronText, "error");
      return;
    }

    setStatus("Última manutenção: " + formatDate(latestRun.completed_at || latestRun.started_at, true) + ". Registros removidos: " + deletedTotal.toLocaleString("pt-BR") + "." + cronText);
  }

  function renderProcessorMetrics() {
    var summary = processorDashboard && processorDashboard.summary || {};
    document.getElementById("processorTotal").textContent = Number(summary.total || 0).toLocaleString("pt-BR");
    document.getElementById("processorVerified").textContent = Number(summary.verified || 0).toLocaleString("pt-BR");
    document.getElementById("processorPending").textContent = Number(summary.pending || 0).toLocaleString("pt-BR");
    document.getElementById("processorActions").textContent = Number(summary.action_required || 0).toLocaleString("pt-BR");
  }

  function renderProcessorRows() {
    var processors = processorDashboard && processorDashboard.processors || [];
    if (!processors.length) {
      processorRowsElement.innerHTML = '<tr><td colspan="7" class="empty">Nenhum fornecedor externo mapeado.</td></tr>';
      return;
    }

    processorRowsElement.innerHTML = processors.map(function (item) {
      var referenceUrl = safeExternalUrl(item.official_reference);
      var reference = referenceUrl ? '<a href="' + escapeHtml(referenceUrl) + '" target="_blank" rel="noopener noreferrer">Referência oficial</a>' : '';
      var categories = Array.isArray(item.data_categories) ? item.data_categories.join(", ") : "";
      var status = processorStatusLabels[item.verification_status] || item.verification_status || "Pendente";

      return '<tr>' +
        '<td class="processor-name"><strong>' + escapeHtml(item.provider_name) + '</strong>' + reference + '</td>' +
        '<td><div>' + escapeHtml(item.service_scope) + '</div><div class="categories">' + escapeHtml(categories) + '</div></td>' +
        '<td class="reason">' + escapeHtml(item.provider_retention) + '</td>' +
        '<td class="reason">' + escapeHtml(item.internal_control) + '</td>' +
        '<td><span class="badge ' + escapeHtml(item.verification_status) + '">' + escapeHtml(status) + '</span></td>' +
        '<td>' + escapeHtml(formatDate(item.next_review_at, false)) + '</td>' +
        '<td><div class="processor-actions">' +
          '<button class="processor-action verified" type="button" data-processor-key="' + escapeHtml(item.processor_key) + '" data-review-status="verified">VERIFICADO</button>' +
          '<button class="processor-action pending" type="button" data-processor-key="' + escapeHtml(item.processor_key) + '" data-review-status="pending">PENDENTE</button>' +
          '<button class="processor-action action_required" type="button" data-processor-key="' + escapeHtml(item.processor_key) + '" data-review-status="action_required">AÇÃO NECESSÁRIA</button>' +
        '</div></td>' +
      '</tr>';
    }).join("");
  }

  function renderProcessorStatus() {
    var summary = processorDashboard && processorDashboard.summary || {};
    var pending = Number(summary.pending || 0);
    var actions = Number(summary.action_required || 0);
    var overdue = Number(summary.overdue || 0);
    if (actions > 0 || overdue > 0) {
      setProcessorStatus("Fornecedores carregados. Ações necessárias: " + actions + ". Revisões vencidas: " + overdue + ".", "error");
      return;
    }
    setProcessorStatus("Fornecedores carregados. Pendentes de conferência externa: " + pending + ".");
  }

  function render() {
    renderMetrics();
    renderRows();
    renderStatus();
    renderProcessorMetrics();
    renderProcessorRows();
    renderProcessorStatus();
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

  async function loadDashboard() {
    refreshButton.disabled = true;
    runButton.disabled = true;
    setStatus("Carregando políticas e histórico de retenção...");
    setProcessorStatus("Carregando fornecedores externos...");
    try {
      var responses = await Promise.all([
        Auth.getClient().rpc("get_data_retention_dashboard"),
        Auth.getClient().rpc("get_external_data_processor_dashboard")
      ]);
      if (responses[0].error) throw responses[0].error;
      if (responses[1].error) throw responses[1].error;
      dashboard = responses[0].data || {};
      processorDashboard = responses[1].data || {};
      render();
    } catch (error) {
      setStatus(error.message || "Não foi possível carregar a governança de retenção.", "error");
      setProcessorStatus(error.message || "Não foi possível carregar os fornecedores externos.", "error");
    } finally {
      refreshButton.disabled = false;
      runButton.disabled = false;
    }
  }

  async function runMaintenance() {
    var eligible = sumEligible(dashboard && dashboard.policies || []);
    var confirmed = window.confirm(
      "Executar a manutenção de retenção agora?\n\nSomente conjuntos marcados como expurgo automático serão afetados. Registros financeiros, solicitações LGPD e dados acadêmicos/cadastrais não serão apagados por esta rotina.\n\nRegistros atualmente elegíveis: " + eligible
    );
    if (!confirmed) return;

    runButton.disabled = true;
    refreshButton.disabled = true;
    runButton.textContent = "EXECUTANDO...";
    setStatus("Executando manutenção de retenção...");

    try {
      var response = await Auth.getClient().rpc("run_data_retention_maintenance_now");
      if (response.error) throw response.error;
      var result = response.data || {};
      if (result.ok === false) throw new Error(result.error || "A manutenção falhou.");
      var deleted = result.deleted_counts || {};
      var deletedTotal = Object.keys(deleted).reduce(function (sum, key) { return sum + Number(deleted[key] || 0); }, 0);
      window.alert("Manutenção concluída. Registros removidos: " + deletedTotal.toLocaleString("pt-BR") + ".");
      await loadDashboard();
    } catch (error) {
      setStatus(error.message || "Não foi possível executar a manutenção.", "error");
    } finally {
      runButton.disabled = false;
      refreshButton.disabled = false;
      runButton.textContent = "EXECUTAR MANUTENÇÃO AGORA";
    }
  }

  async function reviewProcessor(processorKey, reviewStatus, button) {
    var label = processorStatusLabels[reviewStatus] || reviewStatus;
    var note = window.prompt("Registre a evidência ou a providência desta revisão (" + label + "):");
    if (note == null) return;
    note = note.trim();
    if (!note) {
      window.alert("A revisão precisa de uma nota de evidência.");
      return;
    }

    button.disabled = true;
    try {
      var response = await Auth.getClient().rpc("review_external_data_processor", {
        p_processor_key: processorKey,
        p_status: reviewStatus,
        p_note: note
      });
      if (response.error) throw response.error;
      await loadDashboard();
    } catch (error) {
      setProcessorStatus(error.message || "Não foi possível registrar a revisão do fornecedor.", "error");
    } finally {
      button.disabled = false;
    }
  }

  refreshButton.addEventListener("click", loadDashboard);
  runButton.addEventListener("click", runMaintenance);
  processorRowsElement.addEventListener("click", function (event) {
    var button = event.target.closest("button[data-processor-key][data-review-status]");
    if (!button) return;
    reviewProcessor(button.dataset.processorKey, button.dataset.reviewStatus, button);
  });

  (async function init() {
    try {
      if (!await verifyTeacherAccess()) return;
      await loadDashboard();
    } catch (error) {
      setStatus(error.message || "Não foi possível verificar o acesso de professor.", "error");
      setProcessorStatus(error.message || "Não foi possível verificar o acesso de professor.", "error");
    }
  })();
})();