let currentProfessorSession = null;
let weeklyStatusRecords = [];
let activeStatusFilter = "all";
let activeExerciseEditorUserId = null;

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

function installExerciseEditorStyles() {
  if (document.getElementById("teacherExerciseEditorStyles")) return;

  const style = document.createElement("style");
  style.id = "teacherExerciseEditorStyles";
  style.textContent = `
    .student-actions {
      margin-top: 14px;
      padding-top: 14px;
      border-top: 1px solid rgba(255,255,255,0.08);
    }
    .manage-exercises-button,
    .save-exercise-button,
    .close-exercise-editor-button {
      border: 1px solid rgba(129,140,248,0.45);
      border-radius: 9px;
      background: rgba(129,140,248,0.12);
      color: #e0e7ff;
      padding: 9px 12px;
      font: 700 11px/1.2 Georgia, serif;
      letter-spacing: .45px;
      cursor: pointer;
    }
    .manage-exercises-button:hover,
    .save-exercise-button:hover,
    .close-exercise-editor-button:hover {
      border-color: #a5b4fc;
      background: rgba(129,140,248,0.2);
    }
    .manage-exercises-button:disabled,
    .save-exercise-button:disabled {
      cursor: wait;
      opacity: .62;
    }
    .exercise-editor {
      margin-top: 15px;
      padding: 15px;
      border: 1px solid rgba(129,140,248,0.32);
      border-radius: 12px;
      background: rgba(15,23,42,0.72);
    }
    .exercise-editor[hidden] { display: none; }
    .exercise-editor-heading {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 13px;
    }
    .exercise-editor-heading strong {
      color: #f8fafc;
      font-size: 14px;
    }
    .exercise-editor-heading p,
    .exercise-editor-message {
      color: #94a3b8;
      font-size: 12px;
      line-height: 1.5;
      margin: 4px 0 0;
    }
    .teacher-exercise-list {
      display: grid;
      gap: 10px;
    }
    .teacher-exercise-row {
      padding: 13px;
      border: 1px solid rgba(255,255,255,0.09);
      border-radius: 10px;
      background: rgba(255,255,255,0.035);
    }
    .teacher-exercise-row.is-completed {
      border-color: rgba(52,211,153,0.32);
      background: rgba(52,211,153,0.055);
    }
    .teacher-exercise-header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 11px;
    }
    .teacher-exercise-header a {
      color: #f8fafc;
      font-size: 14px;
      font-weight: 700;
      line-height: 1.35;
      text-decoration: none;
    }
    .teacher-exercise-header a:hover { color: #a5b4fc; }
    .teacher-exercise-toggle {
      display: inline-flex;
      align-items: center;
      gap: 7px;
      color: #cbd5e1;
      font-size: 12px;
      white-space: nowrap;
    }
    .teacher-exercise-toggle input {
      width: 18px;
      height: 18px;
      accent-color: #818cf8;
    }
    .teacher-exercise-fields {
      display: grid;
      grid-template-columns: minmax(190px, 1fr) auto;
      gap: 10px;
      align-items: end;
    }
    .teacher-exercise-date-label {
      display: grid;
      gap: 6px;
      color: #94a3b8;
      font-size: 11px;
    }
    .teacher-exercise-date {
      width: 100%;
      min-height: 38px;
      border: 1px solid rgba(148,163,184,0.35);
      border-radius: 8px;
      background: #0f172a;
      color: #f8fafc;
      padding: 8px 9px;
      font: inherit;
      color-scheme: dark;
    }
    .teacher-exercise-date:disabled {
      opacity: .45;
      cursor: not-allowed;
    }
    .teacher-exercise-meta {
      margin-top: 9px;
      color: #94a3b8;
      font-size: 11px;
      line-height: 1.5;
    }
    .teacher-exercise-save-status {
      display: block;
      min-height: 18px;
      margin-top: 7px;
      color: #94a3b8;
      font-size: 11px;
    }
    .teacher-exercise-save-status.success { color: #6ee7b7; }
    .teacher-exercise-save-status.error { color: #fca5a5; }
    @media (max-width: 600px) {
      .exercise-editor-heading,
      .teacher-exercise-header {
        flex-direction: column;
      }
      .teacher-exercise-fields {
        grid-template-columns: 1fr;
      }
      .save-exercise-button,
      .manage-exercises-button,
      .close-exercise-editor-button {
        width: 100%;
      }
    }
  `;
  document.head.appendChild(style);
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

function toDateTimeLocal(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return "";

  const pad = number => String(number).padStart(2, "0");
  return [
    date.getFullYear(), "-", pad(date.getMonth() + 1), "-", pad(date.getDate()),
    "T", pad(date.getHours()), ":", pad(date.getMinutes())
  ].join("");
}

function statusDefinition(status) {
  if (status === "late") return { label: "ATRASADO", cssClass: "late" };
  if (status === "up_to_date") return { label: "SEMANA ATUAL FEITA", cssClass: "done" };
  return { label: "SEMANA ATUAL PENDENTE", cssClass: "pending" };
}

async function loadWeeklyExerciseStatus() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_weekly_exercise_status");
  if (response.error) throw response.error;
  return response.data || [];
}

async function loadStudentExerciseCompletion(userId) {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_student_exercise_completion", {
    target_user_id: userId
  });
  if (response.error) throw response.error;
  return response.data || [];
}

function renderSummary(records) {
  document.getElementById("totalStudentsCount").textContent = records.length;
  document.getElementById("lateStudentsCount").textContent = records.filter(record => record.status === "late").length;
  document.getElementById("overdueWeeksCount").textContent = records.reduce((total, record) => total + toInteger(record.overdue_weeks), 0);
  document.getElementById("currentPendingCount").textContent = records.filter(record => record.status === "current_week_pending").length;
  document.getElementById("currentCompletedCount").textContent = records.filter(record => record.status === "up_to_date").length;
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
  const safeUserId = escapeHtml(record.user_id);

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
    '<div class="student-actions"><button type="button" class="manage-exercises-button" data-user-id="' + safeUserId + '">GERENCIAR EXERCÍCIOS</button></div>' +
    '<div class="exercise-editor" data-editor-user-id="' + safeUserId + '" hidden></div>' +
  '</article>';
}

function filteredRecords() {
  if (activeStatusFilter === "all") return weeklyStatusRecords;
  return weeklyStatusRecords.filter(record => record.status === activeStatusFilter);
}

function setupManageExerciseButtons() {
  document.querySelectorAll(".manage-exercises-button").forEach(button => {
    button.addEventListener("click", () => openExerciseEditor(button.dataset.userId, false));
  });
}

function renderFilteredStudents() {
  const list = document.getElementById("exerciseCompletionList");
  const visibleRecords = filteredRecords();
  const visibleCount = document.getElementById("visibleStudentsCount");

  activeExerciseEditorUserId = null;
  visibleCount.textContent = visibleRecords.length + (visibleRecords.length === 1 ? " aluno exibido" : " alunos exibidos");

  if (!visibleRecords.length) {
    list.className = "empty";
    list.textContent = "Nenhum aluno corresponde a este filtro.";
    return;
  }

  list.className = "student-status-grid";
  list.innerHTML = visibleRecords.map(renderStudentStatus).join("");
  setupManageExerciseButtons();
}

function closeExerciseEditors() {
  document.querySelectorAll(".exercise-editor").forEach(editor => {
    editor.hidden = true;
    editor.innerHTML = "";
  });
  document.querySelectorAll(".manage-exercises-button").forEach(button => {
    button.textContent = "GERENCIAR EXERCÍCIOS";
    button.disabled = false;
  });
  activeExerciseEditorUserId = null;
}

function exerciseSourceText(record) {
  if (!record.completed) return "Não concluído";
  if (record.completion_source === "teacher") {
    return record.completed_by_email
      ? "Registrado pelo professor " + record.completed_by_email
      : "Registrado pelo professor";
  }
  return "Marcado pelo aluno";
}

function renderExerciseEditorRows(editor, userId, records) {
  if (!records.length) {
    editor.innerHTML = '<div class="exercise-editor-heading"><div><strong>Exercícios do aluno</strong><p>Nenhum exercício publicado está disponível.</p></div><button type="button" class="close-exercise-editor-button">FECHAR</button></div>';
    editor.querySelector(".close-exercise-editor-button").addEventListener("click", closeExerciseEditors);
    return;
  }

  editor.innerHTML =
    '<div class="exercise-editor-heading"><div><strong>Exercícios do aluno</strong><p>Marque o exercício e informe a data em que ele foi feito.</p></div><button type="button" class="close-exercise-editor-button">FECHAR</button></div>' +
    '<div class="teacher-exercise-list">' +
      records.map(record => {
        const completed = record.completed === true;
        const localDate = completed ? toDateTimeLocal(record.completed_at) : "";
        return '<div class="teacher-exercise-row ' + (completed ? 'is-completed' : '') + '" data-exercise-id="' + escapeHtml(record.exercise_id) + '">' +
          '<div class="teacher-exercise-header">' +
            '<a href="' + escapeHtml(record.exercise_url) + '" target="_blank" rel="noopener noreferrer">' + escapeHtml(record.exercise_title) + ' ↗</a>' +
            '<label class="teacher-exercise-toggle"><input type="checkbox" class="teacher-completion-checkbox" ' + (completed ? 'checked' : '') + ' /> Concluído</label>' +
          '</div>' +
          '<div class="teacher-exercise-fields">' +
            '<label class="teacher-exercise-date-label">Data e hora em que foi feito<input type="datetime-local" class="teacher-exercise-date" value="' + escapeHtml(localDate) + '" ' + (completed ? '' : 'disabled') + ' /></label>' +
            '<button type="button" class="save-exercise-button">SALVAR</button>' +
          '</div>' +
          '<p class="teacher-exercise-meta">' + escapeHtml(exerciseSourceText(record)) + (completed && record.completed_at ? ' · ' + escapeHtml(formatDate(record.completed_at, true)) : '') + '</p>' +
          '<span class="teacher-exercise-save-status" aria-live="polite"></span>' +
        '</div>';
      }).join("") +
    '</div>';

  editor.querySelector(".close-exercise-editor-button").addEventListener("click", closeExerciseEditors);

  editor.querySelectorAll(".teacher-exercise-row").forEach(row => {
    const checkbox = row.querySelector(".teacher-completion-checkbox");
    const dateInput = row.querySelector(".teacher-exercise-date");
    const saveButton = row.querySelector(".save-exercise-button");

    checkbox.addEventListener("change", () => {
      dateInput.disabled = !checkbox.checked;
      row.classList.toggle("is-completed", checkbox.checked);
      if (checkbox.checked && !dateInput.value) dateInput.value = toDateTimeLocal(new Date());
      if (!checkbox.checked) dateInput.value = "";
    });

    saveButton.addEventListener("click", () => saveTeacherCompletion(userId, row));
  });
}

async function openExerciseEditor(userId, forceOpen) {
  const editor = document.querySelector('[data-editor-user-id="' + userId + '"]');
  const button = document.querySelector('.manage-exercises-button[data-user-id="' + userId + '"]');
  if (!editor || !button) return;

  if (!forceOpen && activeExerciseEditorUserId === userId && !editor.hidden) {
    closeExerciseEditors();
    return;
  }

  closeExerciseEditors();
  activeExerciseEditorUserId = userId;
  editor.hidden = false;
  editor.innerHTML = '<p class="exercise-editor-message">Carregando exercícios...</p>';
  button.textContent = "CARREGANDO...";
  button.disabled = true;

  try {
    const records = await loadStudentExerciseCompletion(userId);
    renderExerciseEditorRows(editor, userId, records);
    button.textContent = "OCULTAR EXERCÍCIOS";
    button.disabled = false;
  } catch (error) {
    editor.innerHTML = '<p class="exercise-editor-message">Não foi possível carregar os exercícios: ' + escapeHtml(error.message || "erro desconhecido") + '.</p>';
    button.textContent = "TENTAR NOVAMENTE";
    button.disabled = false;
  }
}

async function saveTeacherCompletion(userId, row) {
  const checkbox = row.querySelector(".teacher-completion-checkbox");
  const dateInput = row.querySelector(".teacher-exercise-date");
  const saveButton = row.querySelector(".save-exercise-button");
  const status = row.querySelector(".teacher-exercise-save-status");
  const completed = checkbox.checked;
  const exerciseId = row.dataset.exerciseId;
  let completedAt = null;

  status.className = "teacher-exercise-save-status";

  if (completed) {
    if (!dateInput.value) {
      status.className = "teacher-exercise-save-status error";
      status.textContent = "Informe a data e a hora.";
      dateInput.focus();
      return;
    }

    const selectedDate = new Date(dateInput.value);
    if (Number.isNaN(selectedDate.getTime())) {
      status.className = "teacher-exercise-save-status error";
      status.textContent = "Data inválida.";
      return;
    }
    if (selectedDate.getTime() > Date.now() + 5 * 60 * 1000) {
      status.className = "teacher-exercise-save-status error";
      status.textContent = "A data não pode estar no futuro.";
      return;
    }
    completedAt = selectedDate.toISOString();
  }

  saveButton.disabled = true;
  checkbox.disabled = true;
  dateInput.disabled = true;
  status.textContent = "Salvando...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("set_teacher_student_exercise_completion", {
      target_user_id: userId,
      target_exercise_id: exerciseId,
      target_completed: completed,
      target_completed_at: completedAt
    });
    if (response.error) throw response.error;

    status.className = "teacher-exercise-save-status success";
    status.textContent = completed ? "Conclusão registrada." : "Marcação removida.";
    await renderExerciseStatus(userId);
  } catch (error) {
    status.className = "teacher-exercise-save-status error";
    status.textContent = error.message || "Não foi possível salvar.";
    saveButton.disabled = false;
    checkbox.disabled = false;
    dateInput.disabled = !checkbox.checked;
  }
}

function setupFilter() {
  const filter = document.getElementById("statusFilter");
  filter.addEventListener("change", function () {
    activeStatusFilter = filter.value;
    closeExerciseEditors();
    renderFilteredStudents();
  });
}

async function renderExerciseStatus(reopenUserId) {
  const list = document.getElementById("exerciseCompletionList");

  try {
    weeklyStatusRecords = await loadWeeklyExerciseStatus();
    renderSummary(weeklyStatusRecords);
    renderFilteredStudents();
    if (reopenUserId && weeklyStatusRecords.some(record => record.user_id === reopenUserId)) {
      await openExerciseEditor(reopenUserId, true);
    }
  } catch (error) {
    list.className = "error";
    list.textContent = "Não foi possível carregar o acompanhamento semanal: " +
      (error.message || "erro desconhecido") +
      ". Verifique se os SQLs de marcação administrativa foram aplicados no Supabase.";
  }
}

async function guardPage() {
  const status = document.getElementById("adminStatus");
  installExerciseEditorStyles();
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
