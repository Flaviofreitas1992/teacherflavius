let currentProfessorSession = null;
let weeklyStatusRecords = [];
let activeStatusFilter = "all";

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("exercicios_dos_alunos.html");
}

function sleep(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function toInteger(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.max(0, Math.trunc(number)) : 0;
}

function formatDate(value, includeTime) {
  if (!value) return "Não informado";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);

  const options = {
    day: "2-digit",
    month: "2-digit",
    year: "numeric"
  };

  if (includeTime) {
    options.hour = "2-digit";
    options.minute = "2-digit";
  }

  return date.toLocaleString("pt-BR", options);
}

function statusDefinition(status) {
  if (status === "late") {
    return { label: "ATRASADO", cssClass: "late" };
  }
  if (status === "up_to_date") {
    return { label: "SEMANA ATUAL FEITA", cssClass: "done" };
  }
  return { label: "SEMANA ATUAL PENDENTE", cssClass: "pending" };
}

async function loadWeeklyExerciseStatus() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_weekly_exercise_status");
  if (response.error) throw response.error;
  return response.data || [];
}

function renderSummary(records) {
  const totalStudents = records.length;
  const lateStudents = records.filter(record => record.status === "late").length;
  const overdueWeeks = records.reduce((total, record) => total + toInteger(record.overdue_weeks), 0);
  const currentPending = records.filter(record => record.status === "current_week_pending").length;
  const currentCompleted = records.filter(record => record.status === "up_to_date").length;

  document.getElementById("totalStudentsCount").textContent = totalStudents;
  document.getElementById("lateStudentsCount").textContent = lateStudents;
  document.getElementById("overdueWeeksCount").textContent = overdueWeeks;
  document.getElementById("currentPendingCount").textContent = currentPending;
  document.getElementById("currentCompletedCount").textContent = currentCompleted;
}

function renderStudentStatus(record) {
  const status = statusDefinition(record.status);
  const elapsedWeeks = toInteger(record.elapsed_weeks);
  const creditedWeeks = toInteger(record.credited_weeks);
  const overdueWeeks = toInteger(record.overdue_weeks);
  const completedExercises = toInteger(record.completed_exercises);
  const currentWeekNumber = Math.max(1, toInteger(record.current_week_number));
  const currentWeekText = record.current_week_completed
    ? "Exercício concluído nesta semana"
    : "Ainda sem exercício concluído nesta semana";

  return '<article class="student-card exercise-status-card status-' + escapeHtml(status.cssClass) + '">' +
    '<div class="student-heading">' +
      '<div><strong>' + escapeHtml(record.student_name || "Aluno sem nome") + '</strong>' +
      '<p class="student-email">' + escapeHtml(record.student_email || "E-mail não informado") + '</p></div>' +
      '<span class="exercise-status-pill ' + escapeHtml(status.cssClass) + '">' + escapeHtml(status.label) + '</span>' +
    '</div>' +
    '<div class="exercise-metrics">' +
      '<div class="exercise-metric"><span>Semanas vencidas</span><b>' + elapsedWeeks + '</b></div>' +
      '<div class="exercise-metric"><span>Semanas cumpridas</span><b>' + creditedWeeks + '</b></div>' +
      '<div class="exercise-metric ' + (overdueWeeks > 0 ? 'danger' : '') + '"><span>Semanas atrasadas</span><b>' + overdueWeeks + '</b></div>' +
      '<div class="exercise-metric"><span>Exercícios marcados</span><b>' + completedExercises + '</b></div>' +
    '</div>' +
    '<div class="student-details">' +
      '<p><b>Matrícula considerada:</b> ' + escapeHtml(formatDate(record.enrollment_started_at, false)) + '</p>' +
      '<p><b>Semana atual:</b> semana ' + currentWeekNumber + ', de ' + escapeHtml(formatDate(record.current_week_start, false)) + ' até ' + escapeHtml(formatDate(record.current_week_due_at, true)) + '</p>' +
      '<p><b>Situação da semana atual:</b> ' + escapeHtml(currentWeekText) + '</p>' +
      '<p><b>Último exercício concluído:</b> ' + escapeHtml(formatDate(record.last_completed_at, true)) + '</p>' +
    '</div>' +
  '</article>';
}

function filteredRecords() {
  if (activeStatusFilter === "all") return weeklyStatusRecords;
  return weeklyStatusRecords.filter(record => record.status === activeStatusFilter);
}

function renderFilteredStudents() {
  const list = document.getElementById("exerciseCompletionList");
  const visibleRecords = filteredRecords();
  const visibleCount = document.getElementById("visibleStudentsCount");

  visibleCount.textContent = visibleRecords.length + (visibleRecords.length === 1 ? " aluno exibido" : " alunos exibidos");

  if (!visibleRecords.length) {
    list.className = "empty";
    list.textContent = "Nenhum aluno corresponde a este filtro.";
    return;
  }

  list.className = "student-status-grid";
  list.innerHTML = visibleRecords.map(renderStudentStatus).join("");
}

function setupFilter() {
  const filter = document.getElementById("statusFilter");
  filter.addEventListener("change", function () {
    activeStatusFilter = filter.value;
    renderFilteredStudents();
  });
}

async function renderExerciseStatus() {
  const list = document.getElementById("exerciseCompletionList");

  try {
    weeklyStatusRecords = await loadWeeklyExerciseStatus();
    renderSummary(weeklyStatusRecords);
    renderFilteredStudents();
  } catch (error) {
    list.className = "error";
    list.textContent = "Não foi possível carregar o acompanhamento semanal: " +
      (error.message || "erro desconhecido") +
      ". Verifique se o SQL atualizado de supabase_exercicios_diarios.sql foi aplicado no Supabase.";
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
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
  setupFilter();
  await renderExerciseStatus();
}

guardPage();
