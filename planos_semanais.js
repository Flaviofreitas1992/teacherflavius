(function () {
  const FLASHCARD_GOAL = 3;
  let currentSession = null;
  let planRows = [];
  let exercises = [];

  function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }

  async function waitForResources() {
    for (let i = 0; i < 15; i++) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
  }

  function esc(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#039;");
  }

  function formatDate(key) {
    const m = String(key || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
    return m ? m[3] + "/" + m[2] : String(key || "");
  }

  function activityNumber(title) {
    const m = String(title || "").match(/ATIVIDADE\s+(\d+)/i);
    return m ? Number(m[1]) : Number.MAX_SAFE_INTEGER;
  }

  function groupBy(rows, key) {
    const map = new Map();
    (rows || []).forEach(function (row) {
      const value = row[key];
      if (!map.has(value)) map.set(value, []);
      map.get(value).push(row);
    });
    return map;
  }

  async function ensureSnapshots(profiles) {
    const client = Auth.getClient();
    const results = await Promise.all(profiles.map(async function (profile) {
      const response = await client.rpc("ensure_weekly_plan_snapshot", { target_user_id: profile.id });
      if (response.error) {
        console.error("Erro ao criar snapshot de", profile.id, response.error);
        return null;
      }
      return response.data && response.data.length ? response.data[0] : null;
    }));
    return results.filter(Boolean);
  }

  async function loadData() {
    const client = Auth.getClient();
    const profilesResponse = await client.from("profiles")
      .select("id,name,email,enrolled,archived,exercise_schedule_start_date,created_at")
      .eq("enrolled", true)
      .eq("archived", false)
      .order("name", { ascending: true });
    if (profilesResponse.error) throw profilesResponse.error;
    const profiles = profilesResponse.data || [];
    if (!profiles.length) return { profiles: [], snapshots: [], datasets: [] };

    const snapshots = await ensureSnapshots(profiles);
    const starts = snapshots.map(function (s) { return s.week_start; }).sort();
    const ends = snapshots.map(function (s) { return s.week_end; }).sort();
    const minStart = starts[0];
    const maxEnd = ends[ends.length - 1];

    const results = await Promise.all([
      client.rpc("get_public_teacher_exercises"),
      client.from("daily_exercise_completion").select("user_id,exercise_id,completed"),
      client.from("flashcard_practice_days").select("user_id,practice_date").gte("practice_date", minStart).lte("practice_date", maxEnd),
      client.from("study_roadmap_completion").select("user_id,lesson_number,completed"),
      client.from("weekly_student_tasks").select("id,user_id,week_start,week_end,title,description,target_url,completed,completed_at,created_at").gte("week_start", minStart).lte("week_start", maxEnd).order("created_at", { ascending: true }),
      client.from("class_students").select("user_id,class_number"),
      client.from("teacher_classes").select("class_number,class_name,is_active")
    ]);
    results.forEach(function (result) { if (result.error) throw result.error; });

    return { profiles: profiles, snapshots: snapshots, datasets: results.map(function (r) { return r.data || []; }) };
  }

  function buildRows(data) {
    if (!data.profiles.length) return [];
    exercises = (data.datasets[0] || []).map(function (item) {
      return { id: item.exercise_id, title: item.exercise_title, url: item.exercise_url, number: activityNumber(item.exercise_title) };
    }).filter(function (item) { return item.id; }).sort(function (a, b) { return a.number - b.number; });

    const completionsByUser = groupBy(data.datasets[1], "user_id");
    const flashByUser = groupBy(data.datasets[2], "user_id");
    const roadmapByUser = groupBy(data.datasets[3], "user_id");
    const tasksByUser = groupBy(data.datasets[4], "user_id");
    const membershipByUser = new Map((data.datasets[5] || []).filter(function (r) { return r.user_id; }).map(function (r) { return [r.user_id, r.class_number]; }));
    const classByNumber = new Map((data.datasets[6] || []).map(function (r) { return [r.class_number, r.class_name || ("Turma " + r.class_number)]; }));
    const snapshotByUser = new Map(data.snapshots.map(function (s) { return [s.user_id, s]; }));

    return data.profiles.map(function (profile) {
      const snapshot = snapshotByUser.get(profile.id);
      if (!snapshot) return null;
      const completionMap = new Map((completionsByUser.get(profile.id) || []).map(function (r) { return [r.exercise_id, r.completed === true]; }));
      const currentExercise = exercises.find(function (ex) { return ex.number === Number(snapshot.week_number); }) || null;
      const currentExerciseDone = !!(currentExercise && completionMap.get(currentExercise.id) === true);
      const overdue = exercises.filter(function (ex) { return Number.isFinite(ex.number) && ex.number < Number(snapshot.week_number) && completionMap.get(ex.id) !== true; });

      const practiceDates = Array.from(new Set((flashByUser.get(profile.id) || []).filter(function (r) {
        const key = String(r.practice_date).slice(0, 10);
        return key >= snapshot.week_start && key <= snapshot.week_end;
      }).map(function (r) { return String(r.practice_date).slice(0, 10); })));
      const flashDone = practiceDates.length >= FLASHCARD_GOAL;

      const roadmapTarget = snapshot.roadmap_target_lesson ? Number(snapshot.roadmap_target_lesson) : null;
      const roadmapDoneRows = roadmapByUser.get(profile.id) || [];
      const roadmapDone = roadmapTarget == null || roadmapDoneRows.some(function (r) { return Number(r.lesson_number) === roadmapTarget && r.completed === true; });

      const customTasks = (tasksByUser.get(profile.id) || []).filter(function (task) { return String(task.week_start) === String(snapshot.week_start); });
      const items = [];
      if (currentExercise) items.push({ key: "exercise", text: currentExercise.title, done: currentExerciseDone });
      items.push({ key: "overdue", text: "Sem atividades atrasadas", done: overdue.length === 0 });
      items.push({ key: "flashcards", text: "Flashcards em 3 dias", done: flashDone });
      items.push({ key: "roadmap", text: roadmapTarget ? "Lição " + roadmapTarget + " do roteiro" : "Roteiro concluído", done: roadmapDone });
      customTasks.forEach(function (task) { items.push({ key: "custom", text: task.title, done: task.completed === true, id: task.id }); });

      const doneCount = items.filter(function (item) { return item.done; }).length;
      const totalCount = items.length;
      const progress = totalCount ? Math.round(doneCount / totalCount * 100) : 100;
      const classNumber = membershipByUser.get(profile.id);

      return {
        id: profile.id,
        name: profile.name || profile.email || "Aluno",
        email: profile.email || "",
        className: classNumber ? (classByNumber.get(classNumber) || ("Turma " + classNumber)) : "Sem turma",
        snapshot: snapshot,
        currentExercise: currentExercise,
        currentExerciseDone: currentExerciseDone,
        overdue: overdue,
        practiceDates: practiceDates,
        flashDone: flashDone,
        roadmapTarget: roadmapTarget,
        roadmapDone: roadmapDone,
        customTasks: customTasks,
        items: items,
        doneCount: doneCount,
        totalCount: totalCount,
        progress: progress
      };
    }).filter(Boolean).sort(function (a, b) { return a.progress - b.progress || a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" }); });
  }

  function renderSummary() {
    document.getElementById("totalStudents").textContent = String(planRows.length);
    document.getElementById("completeStudents").textContent = String(planRows.filter(function (r) { return r.progress === 100; }).length);
    document.getElementById("attentionStudents").textContent = String(planRows.filter(function (r) { return r.progress < 100; }).length);
    document.getElementById("pendingCustomTasks").textContent = String(planRows.reduce(function (sum, r) { return sum + r.customTasks.filter(function (t) { return !t.completed; }).length; }, 0));
  }

  function renderStudentOptions() {
    const select = document.getElementById("taskStudent");
    const previous = select.value;
    select.innerHTML = '<option value="">Selecione um aluno</option>' + planRows.slice().sort(function (a, b) { return a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" }); }).map(function (row) {
      return '<option value="' + esc(row.id) + '">' + esc(row.name) + ' — ' + esc(row.className) + '</option>';
    }).join("");
    if (previous && planRows.some(function (r) { return r.id === previous; })) select.value = previous;
    updateSelectedWeek();
  }

  function statusText(row) {
    if (row.progress === 100) return "PLANO CONCLUÍDO";
    if (row.progress >= 60) return "EM ANDAMENTO";
    return "PRECISA DE ATENÇÃO";
  }

  function renderRows() {
    const query = document.getElementById("studentSearch").value.trim().toLowerCase();
    const filter = document.getElementById("progressFilter").value;
    const rows = planRows.filter(function (row) {
      const textMatch = !query || row.name.toLowerCase().includes(query) || row.email.toLowerCase().includes(query) || row.className.toLowerCase().includes(query);
      const filterMatch = !filter || (filter === "complete" && row.progress === 100) || (filter === "incomplete" && row.progress < 100) || (filter === "low" && row.progress < 50);
      return textMatch && filterMatch;
    });

    const list = document.getElementById("planList");
    if (!rows.length) {
      list.innerHTML = '<div class="empty">Nenhum aluno corresponde aos filtros selecionados.</div>';
      return;
    }

    list.innerHTML = rows.map(function (row) {
      const autoList = row.items.filter(function (i) { return i.key !== "custom"; }).map(function (item) {
        return '<li class="' + (item.done ? 'done' : 'pending') + '">' + (item.done ? '✓ ' : '○ ') + esc(item.text) + '</li>';
      }).join("");
      const customList = row.customTasks.length ? row.customTasks.map(function (task) {
        return '<div class="custom-task ' + (task.completed ? 'done' : '') + '"><div><strong>' + esc(task.title) + '</strong>' + (task.description ? '<span>' + esc(task.description) + '</span>' : '') + '</div><div class="task-buttons"><button type="button" data-toggle-task="' + esc(task.id) + '" data-task-completed="' + (task.completed ? 'true' : 'false') + '">' + (task.completed ? 'DESFAZER' : 'CONCLUIR') + '</button><button class="danger" type="button" data-delete-task="' + esc(task.id) + '">EXCLUIR</button></div></div>';
      }).join("") : '<div class="muted-line">Nenhuma tarefa individual adicionada.</div>';

      return '<article class="student-plan"><div class="student-head"><div><h2>' + esc(row.name) + '</h2><p>' + esc(row.email) + ' · ' + esc(row.className) + '</p><p>Semana ' + esc(row.snapshot.week_number) + ' · ' + esc(formatDate(row.snapshot.week_start)) + ' a ' + esc(formatDate(row.snapshot.week_end)) + '</p></div><div class="progress-badge">' + row.progress + '%</div></div><div class="bar"><div style="width:' + row.progress + '%"></div></div><div class="metrics"><div><span>Tarefas</span><b>' + row.doneCount + '/' + row.totalCount + '</b></div><div><span>Atividade da semana</span><b>' + (row.currentExercise ? (row.currentExerciseDone ? 'Feita' : 'Pendente') : 'Não publicada') + '</b></div><div><span>Atrasadas</span><b>' + row.overdue.length + '</b></div><div><span>Flashcards</span><b>' + Math.min(row.practiceDates.length, FLASHCARD_GOAL) + '/3</b></div><div><span>Roteiro</span><b>' + (row.roadmapTarget ? ('Lição ' + row.roadmapTarget) : 'Concluído') + '</b></div></div><span class="plan-status">' + esc(statusText(row)) + '</span><details><summary>Ver tarefas da semana</summary><div class="details-grid"><div><h3>Metas automáticas</h3><ul>' + autoList + '</ul></div><div><h3>Tarefas individuais</h3>' + customList + '</div></div></details><div class="card-actions"><button type="button" data-add-for-student="' + esc(row.id) + '">ADICIONAR TAREFA</button><a href="/perfil-dos-alunos/">ABRIR PERFIL DOS ALUNOS</a></div></article>';
    }).join("");

    list.querySelectorAll("[data-add-for-student]").forEach(function (button) {
      button.addEventListener("click", function () {
        document.getElementById("taskStudent").value = button.dataset.addForStudent;
        updateSelectedWeek();
        document.getElementById("taskTitle").focus();
        document.getElementById("taskFormPanel").scrollIntoView({ behavior: "smooth", block: "start" });
      });
    });

    list.querySelectorAll("[data-toggle-task]").forEach(function (button) {
      button.addEventListener("click", function () { toggleTask(button); });
    });
    list.querySelectorAll("[data-delete-task]").forEach(function (button) {
      button.addEventListener("click", function () { deleteTask(button.dataset.deleteTask); });
    });
  }

  function updateSelectedWeek() {
    const userId = document.getElementById("taskStudent").value;
    const row = planRows.find(function (r) { return r.id === userId; });
    document.getElementById("selectedWeek").textContent = row ? ("Semana " + row.snapshot.week_number + " · " + formatDate(row.snapshot.week_start) + " a " + formatDate(row.snapshot.week_end)) : "Selecione um aluno para identificar a semana atual.";
  }

  async function addTask(event) {
    event.preventDefault();
    const userId = document.getElementById("taskStudent").value;
    const title = document.getElementById("taskTitle").value.trim();
    const description = document.getElementById("taskDescription").value.trim();
    const targetUrl = document.getElementById("taskUrl").value.trim();
    const row = planRows.find(function (r) { return r.id === userId; });
    const button = document.getElementById("saveTask");
    const message = document.getElementById("taskMessage");

    if (!row) { message.textContent = "Selecione um aluno."; return; }
    if (!title) { message.textContent = "Digite a tarefa."; return; }

    button.disabled = true;
    button.textContent = "SALVANDO...";
    message.textContent = "";
    try {
      const response = await Auth.getClient().from("weekly_student_tasks").insert({
        user_id: row.id,
        week_start: row.snapshot.week_start,
        week_end: row.snapshot.week_end,
        title: title,
        description: description || null,
        target_url: targetUrl || null,
        created_by: currentSession.user.id
      });
      if (response.error) throw response.error;
      document.getElementById("taskTitle").value = "";
      document.getElementById("taskDescription").value = "";
      document.getElementById("taskUrl").value = "";
      message.textContent = "Tarefa adicionada ao plano semanal do aluno.";
      await refreshPlans(true);
    } catch (error) {
      message.textContent = "Não foi possível adicionar a tarefa: " + (error.message || "erro desconhecido") + ".";
    } finally {
      button.disabled = false;
      button.textContent = "ADICIONAR À SEMANA";
    }
  }

  async function toggleTask(button) {
    const completed = button.dataset.taskCompleted === "true";
    button.disabled = true;
    try {
      const response = await Auth.getClient().rpc("set_my_weekly_task_completed", {
        target_task_id: button.dataset.toggleTask,
        target_completed: !completed
      });
      if (response.error) throw response.error;
      await refreshPlans(true);
    } catch (error) {
      alert("Não foi possível atualizar a tarefa: " + (error.message || "erro desconhecido") + ".");
      button.disabled = false;
    }
  }

  async function deleteTask(taskId) {
    if (!window.confirm("Excluir esta tarefa individual do plano semanal?")) return;
    try {
      const response = await Auth.getClient().from("weekly_student_tasks").delete().eq("id", taskId);
      if (response.error) throw response.error;
      await refreshPlans(true);
    } catch (error) {
      alert("Não foi possível excluir a tarefa: " + (error.message || "erro desconhecido") + ".");
    }
  }

  async function refreshPlans(preserveSelection) {
    const refresh = document.getElementById("refreshPlans");
    const status = document.getElementById("pageStatus");
    const selected = preserveSelection ? document.getElementById("taskStudent").value : "";
    refresh.disabled = true;
    status.textContent = "Atualizando planos semanais...";
    document.getElementById("planList").innerHTML = '<div class="empty">Carregando planos dos alunos...</div>';
    try {
      const data = await loadData();
      planRows = buildRows(data);
      renderSummary();
      renderStudentOptions();
      if (selected && planRows.some(function (r) { return r.id === selected; })) document.getElementById("taskStudent").value = selected;
      updateSelectedWeek();
      renderRows();
      status.textContent = "Planos semanais atualizados.";
    } catch (error) {
      console.error("Erro ao carregar planos semanais:", error);
      status.textContent = "Erro ao carregar os planos semanais.";
      document.getElementById("planList").innerHTML = '<div class="empty">Não foi possível carregar os planos semanais. Atualize a página e tente novamente.</div>';
    } finally {
      refresh.disabled = false;
    }
  }

  async function init() {
    const ready = await waitForResources();
    if (!ready) {
      document.body.classList.remove("auth-checking");
      document.getElementById("pageStatus").textContent = "Não foi possível carregar a autenticação.";
      return;
    }
    currentSession = await Auth.getSession();
    if (!currentSession || !currentSession.user) {
      window.location.href = "/login.html?next=" + encodeURIComponent("/planos-semanais/");
      return;
    }
    try {
      const admin = await Auth.getClient().rpc("is_teacher_admin");
      if (admin.error) throw admin.error;
      if (admin.data !== true) {
        document.body.classList.remove("auth-checking");
        document.getElementById("pageStatus").textContent = "Acesso negado. Esta página é exclusiva do professor.";
        return;
      }
      document.getElementById("content").hidden = false;
      document.body.classList.remove("auth-checking");
      await refreshPlans(false);
    } catch (error) {
      document.body.classList.remove("auth-checking");
      document.getElementById("pageStatus").textContent = "Não foi possível confirmar as credenciais administrativas.";
    }
  }

  document.getElementById("refreshPlans").addEventListener("click", function () { refreshPlans(true); });
  document.getElementById("studentSearch").addEventListener("input", renderRows);
  document.getElementById("progressFilter").addEventListener("change", renderRows);
  document.getElementById("taskStudent").addEventListener("change", updateSelectedWeek);
  document.getElementById("taskForm").addEventListener("submit", addTask);
  init();
})();