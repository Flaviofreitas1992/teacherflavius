let currentProfessorSession = null;
let integrationRefreshTimer = null;

function redirectToLogin() {
  window.location.href = "/login.html?next=" + encodeURIComponent("/integracao-google-forms/");
}

function sleep(ms) {
  return new Promise(function(resolve) { setTimeout(resolve, ms); });
}

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function formatDateTime(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return date.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit"
  });
}

function statusLabel(status) {
  const labels = {
    active: "ATIVA",
    pending: "PENDENTE",
    error: "ERRO",
    disconnect_requested: "DESCONECTANDO",
    disconnected: "DESCONECTADA"
  };
  return labels[status] || String(status || "DESCONHECIDO").toUpperCase();
}

async function loadTeacherExercises() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_created_exercises");
  if (response.error) throw response.error;
  return response.data || [];
}

async function loadIntegrations() {
  const client = Auth.getClient();
  const response = await client.rpc("get_google_form_integrations");
  if (response.error) throw response.error;
  return response.data || [];
}

function renderExerciseOptions(exercises) {
  const select = document.getElementById("exerciseSelect");
  if (!select) return;

  const sorted = (exercises || []).slice().sort(function(a, b) {
    return String(a.exercise_title || "").localeCompare(String(b.exercise_title || ""), "pt-BR", { numeric: true });
  });

  select.innerHTML = '<option value="">Selecione um exercício</option>' + sorted.map(function(exercise) {
    return '<option value="' + escapeHtml(exercise.exercise_id) + '">' +
      escapeHtml(exercise.exercise_title || exercise.exercise_id) +
      '</option>';
  }).join("");
}

function renderIntegrationCard(item) {
  const status = String(item.status || "pending");
  const canRetry = status === "error";
  const canDisconnect = ["active", "pending", "error"].indexOf(status) !== -1;

  let actions = "";
  if (canRetry) {
    actions += '<button class="row-button retry" type="button" data-action="retry" data-id="' + escapeHtml(item.id) + '">TENTAR NOVAMENTE</button>';
  }
  if (canDisconnect) {
    actions += '<button class="row-button danger" type="button" data-action="disconnect" data-id="' + escapeHtml(item.id) + '">DESCONECTAR</button>';
  }

  return '<article class="integration-card">' +
    '<div class="integration-card-head">' +
      '<div>' +
        '<h3 class="integration-title">' + escapeHtml(item.exercise_title || item.exercise_id) + '</h3>' +
        '<a class="integration-url" href="' + escapeHtml(item.spreadsheet_url || "#") + '" target="_blank" rel="noopener noreferrer">' + escapeHtml(item.spreadsheet_url || "") + '</a>' +
      '</div>' +
      '<span class="status-pill status-' + escapeHtml(status) + '">' + escapeHtml(statusLabel(status)) + '</span>' +
    '</div>' +
    '<div class="integration-meta">' +
      '<span><strong>Importação histórica:</strong> ' + (item.import_existing ? "SIM" : "NÃO") + '</span>' +
      '<span><strong>Importados:</strong> ' + Number(item.historical_processed || 0) + '</span>' +
      '<span><strong>Não encontrados:</strong> ' + Number(item.historical_unmatched || 0) + '</span>' +
      '<span><strong>Gatilho:</strong> ' + escapeHtml(formatDateTime(item.trigger_created_at)) + '</span>' +
      '<span><strong>Atualizado:</strong> ' + escapeHtml(formatDateTime(item.updated_at)) + '</span>' +
    '</div>' +
    (item.last_error ? '<div class="integration-error">' + escapeHtml(item.last_error) + '</div>' : '') +
    (actions ? '<div class="integration-actions">' + actions + '</div>' : '') +
  '</article>';
}

function bindRowActions() {
  document.querySelectorAll('[data-action="retry"]').forEach(function(button) {
    button.addEventListener("click", function() {
      retryIntegration(button.dataset.id, button);
    });
  });

  document.querySelectorAll('[data-action="disconnect"]').forEach(function(button) {
    button.addEventListener("click", function() {
      disconnectIntegration(button.dataset.id, button);
    });
  });
}

async function renderIntegrations() {
  const list = document.getElementById("integrationList");
  try {
    const integrations = await loadIntegrations();
    if (!integrations.length) {
      list.innerHTML = '<div class="empty-state">Nenhuma planilha conectada ainda.</div>';
      return;
    }
    list.innerHTML = integrations.map(renderIntegrationCard).join("");
    bindRowActions();
  } catch (error) {
    list.innerHTML = '<div class="empty-state">Não foi possível carregar as integrações: ' + escapeHtml(error.message || "erro desconhecido") + '.</div>';
  }
}

async function createIntegration(event) {
  event.preventDefault();

  const formMessage = document.getElementById("formMessage");
  const connectButton = document.getElementById("connectButton");
  const exerciseId = document.getElementById("exerciseSelect").value;
  const spreadsheetUrl = document.getElementById("spreadsheetUrl").value.trim();
  const importExisting = document.getElementById("importExisting").checked;

  formMessage.className = "form-message";
  formMessage.textContent = "Salvando integração...";
  connectButton.disabled = true;

  try {
    if (!exerciseId) throw new Error("Selecione um exercício.");
    if (!spreadsheetUrl) throw new Error("Cole a URL da planilha de respostas.");

    const client = Auth.getClient();
    const response = await client.rpc("upsert_google_form_integration", {
      target_exercise_id: exerciseId,
      target_spreadsheet_url: spreadsheetUrl,
      target_import_existing: importExisting
    });

    if (response.error) throw response.error;

    document.getElementById("integrationForm").reset();
    document.getElementById("importExisting").checked = true;
    formMessage.className = "form-message success";
    formMessage.textContent = "Planilha cadastrada. O Apps Script fará a ativação automática em até 5 minutos.";
    await renderIntegrations();
  } catch (error) {
    formMessage.className = "form-message error";
    formMessage.textContent = "Não foi possível conectar a planilha: " + (error.message || "erro desconhecido") + ".";
  } finally {
    connectButton.disabled = false;
  }
}

async function retryIntegration(id, button) {
  button.disabled = true;
  try {
    const client = Auth.getClient();
    const response = await client.rpc("retry_google_form_integration", { target_id: id });
    if (response.error) throw response.error;
    await renderIntegrations();
  } catch (error) {
    alert("Não foi possível tentar novamente: " + (error.message || "erro desconhecido"));
    button.disabled = false;
  }
}

async function disconnectIntegration(id, button) {
  const confirmed = window.confirm("Desconectar esta planilha? O gatilho automático será removido pelo Apps Script na próxima verificação.");
  if (!confirmed) return;

  button.disabled = true;
  try {
    const client = Auth.getClient();
    const response = await client.rpc("disconnect_google_form_integration", { target_id: id });
    if (response.error) throw response.error;
    await renderIntegrations();
  } catch (error) {
    alert("Não foi possível solicitar a desconexão: " + (error.message || "erro desconhecido"));
    button.disabled = false;
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentProfessorSession = await Auth.getSession();
  if (!currentProfessorSession || !currentProfessorSession.user) {
    redirectToLogin();
    return;
  }

  status.textContent = "Professor autenticado: " + currentProfessorSession.user.email + ".";
  document.body.classList.remove("auth-checking");

  try {
    const exercises = await loadTeacherExercises();
    renderExerciseOptions(exercises);
    await renderIntegrations();
  } catch (error) {
    status.textContent = "Professor autenticado, mas não foi possível carregar os dados: " + (error.message || "erro desconhecido") + ".";
  }

  if (integrationRefreshTimer) clearInterval(integrationRefreshTimer);
  integrationRefreshTimer = setInterval(function() {
    if (!document.hidden) renderIntegrations();
  }, 15000);
}

const integrationForm = document.getElementById("integrationForm");
if (integrationForm) integrationForm.addEventListener("submit", createIntegration);

const refreshButton = document.getElementById("refreshButton");
if (refreshButton) {
  refreshButton.addEventListener("click", async function() {
    refreshButton.disabled = true;
    await renderIntegrations();
    refreshButton.disabled = false;
  });
}

guardPage();
