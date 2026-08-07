(function () {
  const TZ = "America/Sao_Paulo";
  const FLASHCARD_GOAL = 3;
  let currentUser = null;
  let currentSnapshot = null;

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

  function pill(text, kind) {
    return '<span class="card-status ' + kind + '">' + esc(text) + '</span>';
  }

  function action(href, text) {
    return '<a class="card-action" href="' + esc(href) + '">' + esc(text) + '</a>';
  }

  async function loadProfile() {
    const response = await Auth.getClient().from("profiles")
      .select("id,name,email,enrolled,enrollment_code,exercise_schedule_start_date,created_at,archived")
      .eq("id", currentUser.id).limit(1);
    if (response.error) throw response.error;
    return response.data && response.data.length ? response.data[0] : null;
  }

  async function ensureSnapshot() {
    const response = await Auth.getClient().rpc("ensure_weekly_plan_snapshot", { target_user_id: currentUser.id });
    if (response.error) throw response.error;
    return response.data && response.data.length ? response.data[0] : null;
  }

  async function loadExercises() {
    const response = await Auth.getClient().rpc("get_public_teacher_exercises");
    if (response.error) throw response.error;
    return (response.data || []).map(function (item) {
      return {
        id: item.exercise_id,
        title: item.exercise_title,
        url: item.exercise_url,
        number: activityNumber(item.exercise_title)
      };
    }).filter(function (item) { return item.id; }).sort(function (a, b) { return a.number - b.number; });
  }

  async function loadExerciseCompletions() {
    const response = await Auth.getClient().from("daily_exercise_completion")
      .select("exercise_id,completed")
      .eq("user_id", currentUser.id);
    if (response.error) throw response.error;
    return new Map((response.data || []).map(function (row) { return [row.exercise_id, row.completed === true]; }));
  }

  async function loadRoadmap() {
    const response = await Auth.getClient().from("study_roadmap_completion")
      .select("lesson_number,completed")
      .eq("user_id", currentUser.id);
    if (response.error) throw response.error;
    const map = new Map();
    (response.data || []).forEach(function (row) {
      if (Number.isFinite(Number(row.lesson_number))) map.set(Number(row.lesson_number), row.completed === true);
    });
    return map;
  }

  async function loadFlashcards(weekStart, weekEnd) {
    const response = await Auth.getClient().from("flashcard_practice_days")
      .select("practice_date")
      .eq("user_id", currentUser.id)
      .gte("practice_date", weekStart)
      .lte("practice_date", weekEnd)
      .order("practice_date", { ascending: true });
    if (response.error) throw response.error;
    return Array.from(new Set((response.data || []).map(function (row) { return String(row.practice_date).slice(0, 10); })));
  }

  async function loadCustomTasks(weekStart) {
    const response = await Auth.getClient().from("weekly_student_tasks")
      .select("id,title,description,target_url,completed,completed_at,week_start,week_end")
      .eq("user_id", currentUser.id)
      .eq("week_start", weekStart)
      .order("created_at", { ascending: true });
    if (response.error) throw response.error;
    return response.data || [];
  }

  async function loadGrammar() {
    const client = Auth.getClient();
    const results = await Promise.all([
      client.from("grammar_lessons").select("id,title,created_at").order("created_at", { ascending: true }),
      client.from("grammar_lesson_completion").select("lesson_id,completed").eq("user_id", currentUser.id)
    ]);
    results.forEach(function (result) { if (result.error) throw result.error; });
    const lessons = results[0].data || [];
    const completed = new Map((results[1].data || []).map(function (row) { return [row.lesson_id, row.completed === true]; }));
    const doneCount = lessons.filter(function (lesson) { return completed.get(lesson.id) === true; }).length;
    const next = lessons.find(function (lesson) { return completed.get(lesson.id) !== true; }) || null;
    return { total: lessons.length, completed: doneCount, next: next };
  }

  async function loadClassInfo() {
    const client = Auth.getClient();
    const membership = await client.from("class_students").select("class_number").eq("user_id", currentUser.id).limit(1);
    if (membership.error) throw membership.error;
    if (!membership.data || !membership.data.length) return null;
    const classNumber = membership.data[0].class_number;
    const classResponse = await client.from("teacher_classes").select("class_number,class_name").eq("class_number", classNumber).limit(1);
    if (classResponse.error) throw classResponse.error;
    return classResponse.data && classResponse.data.length ? classResponse.data[0] : { class_number: classNumber, class_name: "Turma " + classNumber };
  }

  function renderChecklist(items) {
    const checklist = document.getElementById("checklist");
    checklist.innerHTML = items.map(function (item) {
      const stateClass = item.done ? "done" : (item.neutral ? "neutral" : "pending");
      const stateText = item.done ? "CONCLUÍDA" : (item.neutral ? "NÃO SE APLICA" : "PENDENTE");
      const customButton = item.custom
        ? '<button class="mini-button" type="button" data-task-id="' + esc(item.id) + '" data-completed="' + (item.done ? 'true' : 'false') + '">' + (item.done ? 'DESFAZER' : 'MARCAR COMO FEITA') + '</button>'
        : '';
      return '<div class="check-item"><div class="check-main"><span class="check-icon">' + esc(item.icon) + '</span><div class="check-text">' + esc(item.text) + (item.sub ? '<span class="check-sub">' + esc(item.sub) + '</span>' : '') + '</div></div><div class="check-actions"><span class="check-state ' + stateClass + '">' + stateText + '</span>' + customButton + '</div></div>';
    }).join("");

    checklist.querySelectorAll("[data-task-id]").forEach(function (button) {
      button.addEventListener("click", async function () {
        const taskId = button.dataset.taskId;
        const completed = button.dataset.completed === "true";
        button.disabled = true;
        try {
          const response = await Auth.getClient().rpc("set_my_weekly_task_completed", {
            target_task_id: taskId,
            target_completed: !completed
          });
          if (response.error) throw response.error;
          await refreshDashboard();
        } catch (error) {
          alert("Não foi possível atualizar a tarefa: " + (error.message || "erro desconhecido") + ".");
          button.disabled = false;
        }
      });
    });
  }

  function renderCards(state) {
    const exerciseCard = document.getElementById("exerciseCard");
    const overdueCard = document.getElementById("overdueCard");
    const roadmapCard = document.getElementById("roadmapCard");
    const flashcardCard = document.getElementById("flashcardCard");
    const customCard = document.getElementById("customCard");
    const grammarCard = document.getElementById("grammarCard");
    const classCard = document.getElementById("classCard");

    if (state.currentExercise) {
      const done = state.currentExerciseDone;
      exerciseCard.className = "week-card " + (done ? "good" : "current");
      exerciseCard.innerHTML = '<div class="card-kicker">Atividade da semana</div><div class="card-title">' + esc(state.currentExercise.title) + '</div><div class="card-text">Esta é a atividade correspondente à Semana ' + esc(state.snapshot.week_number) + '.</div>' + pill(done ? "CONCLUÍDA" : "FAZER ESTA SEMANA", done ? "done" : "info") + action(state.currentExercise.url || "/exercicios-diarios/", done ? "ABRIR ATIVIDADE" : "FAZER ATIVIDADE");
    } else {
      exerciseCard.className = "week-card current";
      exerciseCard.innerHTML = '<div class="card-kicker">Atividade da semana</div><div class="card-title">Aguardando publicação</div><div class="card-text">A atividade correspondente à Semana ' + esc(state.snapshot.week_number) + ' ainda não está disponível.</div>' + pill("NÃO PREJUDICA O PROGRESSO", "warning") + action("/exercicios-diarios/", "ABRIR PORTAL DE EXERCÍCIOS");
    }

    if (state.overdue.length) {
      overdueCard.className = "week-card overdue";
      overdueCard.innerHTML = '<div class="card-kicker">Pendências anteriores</div><div class="card-title">' + state.overdue.length + ' atividade(s) atrasada(s)</div><div class="card-text">Comece pela ' + esc(state.overdue[0].title) + ' e siga em ordem.</div>' + pill("PRECISA DE ATENÇÃO", "pending") + action(state.overdue[0].url || "/exercicios-diarios/", "FAZER A MAIS ANTIGA");
    } else {
      overdueCard.className = "week-card good";
      overdueCard.innerHTML = '<div class="card-kicker">Pendências anteriores</div><div class="card-title">Nenhuma atividade atrasada</div><div class="card-text">Você está em dia com as semanas anteriores.</div>' + pill("EM DIA", "done") + action("/meu_progresso.html", "VER PROGRESSO");
    }

    if (state.roadmapTarget) {
      roadmapCard.className = "week-card " + (state.roadmapDone ? "good" : "current");
      roadmapCard.innerHTML = '<div class="card-kicker">Roteiro de Estudos</div><div class="card-title">Meta da semana: Lição ' + esc(state.roadmapTarget) + '</div><div class="card-text">Esta lição fica definida como sua meta até o fim desta semana, mesmo que você avance para a seguinte.</div>' + pill(state.roadmapDone ? "META CONCLUÍDA" : "PRÓXIMA LIÇÃO", state.roadmapDone ? "done" : "info") + action("/roteiro-de-estudos/", "ABRIR ROTEIRO DE ESTUDOS");
    } else {
      roadmapCard.className = "week-card good";
      roadmapCard.innerHTML = '<div class="card-kicker">Roteiro de Estudos</div><div class="card-title">Roteiro concluído</div><div class="card-text">Todas as lições disponíveis foram concluídas.</div>' + pill("CONCLUÍDO", "done") + action("/roteiro-de-estudos/", "ABRIR ROTEIRO");
    }

    flashcardCard.className = "week-card " + (state.flashDone ? "good" : "current");
    const practiceCircles = Array.from({ length: FLASHCARD_GOAL }).map(function (_, index) {
      return '<span class="practice-day ' + (index < state.practiceDates.length ? 'done' : '') + '">' + (index + 1) + '</span>';
    }).join("");
    flashcardCard.innerHTML = '<div class="card-kicker">Flashcards</div><div class="card-title">' + Math.min(state.practiceDates.length, FLASHCARD_GOAL) + '/3 dias praticados</div><div class="card-text">A meta é praticar em três dias distintos desta semana.</div><div class="practice-days">' + practiceCircles + '</div>' + pill(state.flashDone ? "META ATINGIDA" : "META EM ANDAMENTO", state.flashDone ? "done" : "warning") + action("/flashcards/", "PRATICAR FLASHCARDS");

    if (state.customTasks.length) {
      customCard.className = "week-card " + (state.customTasks.every(function (t) { return t.completed; }) ? "good" : "current");
      customCard.innerHTML = '<div class="card-kicker">Tarefas do professor</div><div class="card-title">' + state.customTasks.filter(function (t) { return t.completed; }).length + '/' + state.customTasks.length + ' concluídas</div><div class="card-text">Tarefas individuais adicionadas pelo professor para esta semana.</div><div class="custom-list">' + state.customTasks.map(function (task) { return '<div class="custom-line ' + (task.completed ? 'done' : '') + '">' + esc(task.title) + '</div>'; }).join('') + '</div>' + pill(state.customTasks.every(function (t) { return t.completed; }) ? "TUDO CONCLUÍDO" : "HÁ TAREFAS PENDENTES", state.customTasks.every(function (t) { return t.completed; }) ? "done" : "info");
    } else {
      customCard.className = "week-card good";
      customCard.innerHTML = '<div class="card-kicker">Tarefas do professor</div><div class="card-title">Nenhuma tarefa extra</div><div class="card-text">Não há tarefas individuais adicionais para esta semana.</div>' + pill("SEM TAREFAS EXTRAS", "done");
    }

    if (state.grammar.total) {
      grammarCard.className = "week-card";
      grammarCard.innerHTML = '<div class="card-kicker">Aulas de gramática</div><div class="card-title">' + state.grammar.completed + '/' + state.grammar.total + ' concluídas</div><div class="card-text">' + (state.grammar.next ? 'Próxima aula pendente: ' + esc(state.grammar.next.title) + '.' : 'Todas as aulas disponíveis foram concluídas.') + '</div>' + pill(state.grammar.next ? "PROGRESSO CONTÍNUO" : "CONCLUÍDO", state.grammar.next ? "info" : "done") + action("/aulas-de-gramatica.html", "ABRIR AULAS DE GRAMÁTICA");
    } else {
      grammarCard.className = "week-card";
      grammarCard.innerHTML = '<div class="card-kicker">Aulas de gramática</div><div class="card-title">Sem aulas cadastradas</div><div class="card-text">Quando houver aulas de gramática disponíveis, o progresso aparecerá aqui.</div>' + pill("INFORMATIVO", "warning");
    }

    classCard.className = "week-card";
    classCard.innerHTML = '<div class="card-kicker">Minha turma</div><div class="card-title">' + esc(state.classInfo ? (state.classInfo.class_name || ("Turma " + state.classInfo.class_number)) : "Sem turma atribuída") + '</div><div class="card-text">Consulte as informações da sua turma e acompanhe sua organização de aulas.</div>' + pill(state.classInfo ? "TURMA ATIVA" : "SEM TURMA", state.classInfo ? "info" : "warning") + action("/minha-turma/", "ABRIR MINHA TURMA");
  }

  async function refreshDashboard() {
    const loading = document.getElementById("loadingPanel");
    const dashboard = document.getElementById("dashboard");
    const status = document.getElementById("pageStatus");
    loading.style.display = "block";
    loading.textContent = "Atualizando seu plano semanal...";
    dashboard.hidden = true;

    try {
      const profile = await loadProfile();
      if (!profile || profile.enrolled !== true) {
        loading.textContent = "Seu perfil não está com matrícula ativa.";
        status.textContent = "Matrícula não encontrada.";
        return;
      }
      if (profile.archived === true) {
        loading.textContent = "Sua matrícula está arquivada ou pausada. O plano semanal fica suspenso enquanto o aluno estiver arquivado.";
        status.textContent = "Plano semanal suspenso.";
        return;
      }

      currentSnapshot = await ensureSnapshot();
      if (!currentSnapshot) throw new Error("Não foi possível definir a semana atual.");

      const base = await Promise.all([loadExercises(), loadExerciseCompletions(), loadRoadmap(), loadFlashcards(currentSnapshot.week_start, currentSnapshot.week_end), loadCustomTasks(currentSnapshot.week_start)]);
      const optional = await Promise.allSettled([loadGrammar(), loadClassInfo()]);

      const exercises = base[0];
      const completions = base[1];
      const roadmap = base[2];
      const practiceDates = base[3];
      const customTasks = base[4];
      const grammar = optional[0].status === "fulfilled" ? optional[0].value : { total: 0, completed: 0, next: null };
      const classInfo = optional[1].status === "fulfilled" ? optional[1].value : null;

      const currentExercise = exercises.find(function (exercise) { return exercise.number === Number(currentSnapshot.week_number); }) || null;
      const currentExerciseDone = !!(currentExercise && completions.get(currentExercise.id) === true);
      const overdue = exercises.filter(function (exercise) {
        return Number.isFinite(exercise.number) && exercise.number < Number(currentSnapshot.week_number) && completions.get(exercise.id) !== true;
      }).sort(function (a, b) { return a.number - b.number; });
      const flashDone = practiceDates.length >= FLASHCARD_GOAL;
      const roadmapTarget = currentSnapshot.roadmap_target_lesson ? Number(currentSnapshot.roadmap_target_lesson) : null;
      const roadmapDone = roadmapTarget == null || roadmap.get(roadmapTarget) === true;

      const items = [];
      if (currentExercise) items.push({ icon: "📝", text: "Concluir " + currentExercise.title, sub: "Atividade correspondente à Semana " + currentSnapshot.week_number, done: currentExerciseDone });
      items.push({ icon: "✅", text: "Ficar sem atividades atrasadas", sub: overdue.length ? overdue.length + " atividade(s) anterior(es) pendente(s)" : "Sem pendências de semanas anteriores", done: overdue.length === 0 });
      items.push({ icon: "🧠", text: "Praticar flashcards em 3 dias diferentes", sub: Math.min(practiceDates.length, FLASHCARD_GOAL) + "/3 dias registrados", done: flashDone });
      items.push({ icon: "📚", text: roadmapTarget ? "Preparar e apresentar a Lição " + roadmapTarget : "Roteiro de Estudos concluído", sub: roadmapTarget ? "Meta fixada para esta semana" : "Todas as lições disponíveis foram concluídas", done: roadmapDone });
      customTasks.forEach(function (task) {
        items.push({ icon: "🎯", text: task.title, sub: task.description || "Tarefa individual do professor", done: task.completed === true, custom: true, id: task.id });
      });

      const completedCount = items.filter(function (item) { return item.done; }).length;
      const totalCount = items.length;
      const percent = totalCount ? Math.round(completedCount / totalCount * 100) : 100;

      document.getElementById("weekIntro").innerHTML = '<strong>Semana ' + esc(currentSnapshot.week_number) + '</strong> · ' + esc(formatDate(currentSnapshot.week_start)) + ' a ' + esc(formatDate(currentSnapshot.week_end)) + '. Este painel mostra exatamente o que precisa ser priorizado agora.';
      document.getElementById("progressNumber").textContent = percent + "%";
      document.getElementById("progressFill").style.width = percent + "%";
      document.getElementById("progressCaption").textContent = completedCount + " de " + totalCount + " tarefa(s) concluída(s).";
      renderChecklist(items);
      renderCards({ snapshot: currentSnapshot, currentExercise: currentExercise, currentExerciseDone: currentExerciseDone, overdue: overdue, roadmapTarget: roadmapTarget, roadmapDone: roadmapDone, practiceDates: practiceDates, flashDone: flashDone, customTasks: customTasks, grammar: grammar, classInfo: classInfo });

      loading.style.display = "none";
      dashboard.hidden = false;
      status.textContent = "Plano semanal atualizado.";
    } catch (error) {
      console.error("Erro ao carregar Minha Semana:", error);
      loading.textContent = "Não foi possível carregar seu plano semanal. Atualize a página e tente novamente.";
      status.textContent = "Erro ao carregar o plano semanal.";
    }
  }

  async function init() {
    const ready = await waitForResources();
    if (!ready) {
      document.body.classList.remove("auth-checking");
      document.getElementById("loadingPanel").textContent = "Não foi possível carregar a autenticação.";
      return;
    }

    const session = await Auth.getSession();
    if (!session || !session.user) {
      window.location.href = "/login.html?next=" + encodeURIComponent("/minha-semana/");
      return;
    }

    currentUser = session.user;
    document.body.classList.remove("auth-checking");
    await refreshDashboard();
  }

  init();
})();