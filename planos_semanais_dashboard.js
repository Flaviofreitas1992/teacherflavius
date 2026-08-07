(function () {
  const FLASHCARD_WEEKLY_GOAL = 3;
  const CUTOFF = "2026-07-30";
  const DAY_MS = 86400000;
  let rows = [];

  function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }
  async function waitForResources() {
    for (let i=0;i<15;i++) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
  }

  function esc(value) {
    return String(value == null ? "" : value).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#039;");
  }

  function dateKeyInSaoPaulo(value) {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    const parts = new Intl.DateTimeFormat("en-CA", { timeZone:"America/Sao_Paulo", year:"numeric", month:"2-digit", day:"2-digit" }).formatToParts(date);
    const v = {};
    parts.forEach(function (part) { if (part.type !== "literal") v[part.type] = part.value; });
    return v.year + "-" + v.month + "-" + v.day;
  }

  function keyToMs(key) {
    const m = String(key || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
    return m ? Date.UTC(Number(m[1]), Number(m[2])-1, Number(m[3])) : NaN;
  }

  function msToKey(ms) {
    const d = new Date(ms);
    return d.getUTCFullYear() + "-" + String(d.getUTCMonth()+1).padStart(2,"0") + "-" + String(d.getUTCDate()).padStart(2,"0");
  }

  function addDays(key, days) { return msToKey(keyToMs(key) + days * DAY_MS); }

  function formatDate(key) {
    const m = String(key || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
    return m ? m[3] + "/" + m[2] : String(key || "");
  }

  function getWeek(profile) {
    const start = profile.exercise_schedule_start_date ? String(profile.exercise_schedule_start_date).slice(0,10) : (dateKeyInSaoPaulo(profile.created_at) || CUTOFF);
    const normalizedStart = start <= CUTOFF ? CUTOFF : start;
    const today = dateKeyInSaoPaulo(new Date());
    const elapsed = Math.max(0, Math.floor((keyToMs(today) - keyToMs(normalizedStart)) / DAY_MS));
    const number = Math.floor(elapsed / 7) + 1;
    const weekStart = addDays(normalizedStart, (number - 1) * 7);
    return { number:number, start:weekStart, end:addDays(weekStart, 6) };
  }

  function activityNumber(title) {
    const m = String(title || "").match(/ATIVIDADE\s+(\d+)/i);
    return m ? Number(m[1]) : Number.MAX_SAFE_INTEGER;
  }

  function normalize(value) {
    return String(value || "").trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  }
  function isPresent(value) {
    const s = normalize(value);
    return s.includes("compareceu") || s === "presente" || s === "present";
  }

  function weekdayLabel(value) {
    return ({1:"segunda-feira",2:"terça-feira",3:"quarta-feira",4:"quinta-feira",5:"sexta-feira",6:"sábado",7:"domingo"})[Number(value)] || "dia não definido";
  }

  function timeLabel(value) {
    const m = String(value || "").match(/^(\d{2}):(\d{2})/);
    if (!m) return "horário não definido";
    const h = Number(m[1]);
    const min = Number(m[2]);
    return min === 0 ? h + "h" : h + "h" + String(min).padStart(2,"0");
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

  async function loadData() {
    const client = Auth.getClient();
    const profilesResponse = await client.from("profiles")
      .select("id,name,email,created_at,exercise_schedule_start_date")
      .eq("enrolled", true).eq("archived", false).order("name", { ascending:true });
    if (profilesResponse.error) throw profilesResponse.error;
    const profiles = profilesResponse.data || [];
    if (!profiles.length) return { profiles:[], datasets:[] };

    const weeks = profiles.map(function (p) { return getWeek(p); });
    const minStart = weeks.map(function (w) { return w.start; }).sort()[0];
    const maxEnd = weeks.map(function (w) { return w.end; }).sort().slice(-1)[0];

    const results = await Promise.all([
      client.rpc("get_public_teacher_exercises"),
      client.from("daily_exercise_completion").select("user_id,exercise_id,completed"),
      client.from("flashcard_practice_days").select("user_id,practice_date").gte("practice_date", minStart).lte("practice_date", maxEnd),
      client.from("grammar_lessons").select("id,title,created_at").order("created_at", { ascending:true }),
      client.from("grammar_lesson_completion").select("user_id,lesson_id,completed,completed_at"),
      client.from("student_frequency").select("user_id,class_date,attendance_status").gte("class_date", minStart).lte("class_date", maxEnd),
      client.from("class_students").select("user_id,class_number"),
      client.from("teacher_classes").select("class_number,class_name,class_weekday,class_start_time,is_active"),
      client.from("study_roadmap_completion").select("user_id,lesson_number,completed")
    ]);
    results.forEach(function (r) { if (r.error) throw r.error; });
    return { profiles:profiles, datasets:results.map(function (r) { return r.data || []; }) };
  }

  function buildRows(data) {
    const exercises = (data.datasets[0] || []).map(function (item) {
      return { id:item.exercise_id, title:item.exercise_title, number:activityNumber(item.exercise_title) };
    }).filter(function (item) { return item.id; }).sort(function (a,b) { return a.number-b.number; });
    const completionByUser = groupBy(data.datasets[1], "user_id");
    const flashByUser = groupBy(data.datasets[2], "user_id");
    const grammarLessons = data.datasets[3] || [];
    const grammarByUser = groupBy(data.datasets[4], "user_id");
    const frequencyByUser = groupBy(data.datasets[5], "user_id");
    const classNumberByUser = new Map((data.datasets[6] || []).filter(function (r) { return r.user_id; }).map(function (r) { return [r.user_id, r.class_number]; }));
    const classByNumber = new Map((data.datasets[7] || []).map(function (r) { return [r.class_number, r]; }));
    const roadmapByUser = groupBy(data.datasets[8], "user_id");

    return data.profiles.map(function (profile) {
      const week = getWeek(profile);
      const completions = new Map((completionByUser.get(profile.id) || []).map(function (r) { return [r.exercise_id, r.completed === true]; }));
      const currentExercise = exercises.find(function (ex) { return ex.number === week.number; }) || null;
      const overdue = exercises.filter(function (ex) { return Number.isFinite(ex.number) && ex.number < week.number && completions.get(ex.id) !== true; });
      const currentDone = !!(currentExercise && completions.get(currentExercise.id) === true);

      const practices = new Set((flashByUser.get(profile.id) || []).filter(function (r) {
        const key = String(r.practice_date).slice(0,10);
        return key >= week.start && key <= week.end;
      }).map(function (r) { return String(r.practice_date).slice(0,10); }));
      const flashDone = practices.size >= FLASHCARD_WEEKLY_GOAL;

      const grammarRows = grammarByUser.get(profile.id) || [];
      const grammarDoneThisWeek = grammarRows.some(function (r) {
        if (r.completed !== true || !r.completed_at) return false;
        const key = dateKeyInSaoPaulo(r.completed_at);
        return key >= week.start && key <= week.end;
      });
      const completedGrammar = new Set(grammarRows.filter(function (r) { return r.completed === true; }).map(function (r) { return r.lesson_id; }));
      const nextGrammar = grammarLessons.find(function (lesson) { return !completedGrammar.has(lesson.id); }) || null;
      const grammarTrackable = grammarDoneThisWeek || !!nextGrammar;

      const frequencyRows = frequencyByUser.get(profile.id) || [];
      const classDone = frequencyRows.some(function (r) { return isPresent(r.attendance_status); });
      const classNumber = classNumberByUser.get(profile.id);
      const classInfo = classNumber ? classByNumber.get(classNumber) : null;
      const classTrackable = classDone || !!(classInfo && classInfo.class_weekday && classInfo.class_start_time);

      const roadmapCompleted = new Set((roadmapByUser.get(profile.id) || []).filter(function (r) { return r.completed === true; }).map(function (r) { return Number(r.lesson_number); }));
      let nextRoadmap = null;
      for (let n=1;n<=24;n++) { if (!roadmapCompleted.has(n)) { nextRoadmap=n; break; } }

      const tasks = [];
      if (classTrackable) tasks.push({ done:classDone, text:classDone ? "Aula da semana realizada" : "Aula da semana pendente" });
      overdue.forEach(function (ex) { tasks.push({ done:false, text:ex.title + " atrasada" }); });
      if (currentExercise) tasks.push({ done:currentDone, text:currentExercise.title + (currentDone ? " concluída" : " fazer esta semana") });
      tasks.push({ done:flashDone, text:"Flashcards: " + Math.min(practices.size,3) + "/3 dias" });
      if (grammarTrackable) tasks.push({ done:grammarDoneThisWeek, text:grammarDoneThisWeek ? "Aula de gramática realizada" : "Aula de gramática pendente" });

      const done = tasks.filter(function (t) { return t.done; }).length;
      const total = tasks.length;
      const progress = total ? Math.round(done / total * 100) : 100;
      const pending = tasks.filter(function (t) { return !t.done; }).map(function (t) { return t.text; });
      const schedule = classInfo && classInfo.class_weekday && classInfo.class_start_time ? weekdayLabel(classInfo.class_weekday) + ", " + timeLabel(classInfo.class_start_time) : "horário não configurado";

      return {
        id:profile.id, name:profile.name || profile.email || "Aluno", email:profile.email || "",
        className:classInfo ? (classInfo.class_name || ("Turma " + classNumber)) : "Sem turma",
        schedule:schedule, week:week, progress:progress, done:done, total:total, pending:pending,
        nextRoadmap:nextRoadmap, practices:practices.size, overdueCount:overdue.length
      };
    }).sort(function (a,b) { return a.progress-b.progress || a.name.localeCompare(b.name,"pt-BR",{sensitivity:"base"}); });
  }

  function renderSummary() {
    document.getElementById("totalStudents").textContent = String(rows.length);
    document.getElementById("completeStudents").textContent = String(rows.filter(function (r) { return r.progress === 100; }).length);
    document.getElementById("pendingStudents").textContent = String(rows.filter(function (r) { return r.progress < 100; }).length);
    document.getElementById("lowStudents").textContent = String(rows.filter(function (r) { return r.progress < 50; }).length);
  }

  function renderRows() {
    const q = document.getElementById("studentSearch").value.trim().toLowerCase();
    const filter = document.getElementById("progressFilter").value;
    const filtered = rows.filter(function (row) {
      const text = (row.name + " " + row.email + " " + row.className).toLowerCase();
      const matches = !q || text.includes(q);
      const status = !filter || (filter === "pending" && row.progress < 100) || (filter === "complete" && row.progress === 100) || (filter === "low" && row.progress < 50);
      return matches && status;
    });

    const list = document.getElementById("studentList");
    if (!filtered.length) {
      list.innerHTML = '<div class="empty">Nenhum aluno corresponde aos filtros selecionados.</div>';
      return;
    }

    list.innerHTML = filtered.map(function (row) {
      const pendingHtml = row.pending.length ? '<div class="pending-list">' + row.pending.map(function (item) { return '<div class="pending-item">' + esc(item) + '</div>'; }).join('') + '</div>' : '<div class="all-done">Todas as tarefas contabilizadas da semana estão concluídas.</div>';
      return '<article class="student-card"><div class="student-head"><div><div class="student-name">' + esc(row.name) + '</div><div class="student-meta">' + esc(row.email) + ' · ' + esc(row.className) + '<br>Semana ' + row.week.number + ' · ' + esc(formatDate(row.week.start)) + ' a ' + esc(formatDate(row.week.end)) + ' · Aula: ' + esc(row.schedule) + '</div></div><div class="progress-badge">' + row.progress + '%</div></div><div class="bar"><div style="width:' + row.progress + '%"></div></div><div class="pending-title">Pendências desta semana</div>' + pendingHtml + '<div class="info-line">Flashcards: ' + Math.min(row.practices,3) + '/3 dias · Atividades atrasadas: ' + row.overdueCount + ' · Próxima lição do roteiro: ' + (row.nextRoadmap ? 'Lição ' + row.nextRoadmap : 'Roteiro concluído') + '</div><div class="card-actions"><a href="/perfil-dos-alunos/">ABRIR ALUNOS</a><a href="/radar-de-alunos/">ABRIR RADAR</a></div></article>';
    }).join("");
  }

  async function refresh() {
    const button = document.getElementById("refreshPlans");
    button.disabled = true;
    document.getElementById("studentList").innerHTML = '<div class="empty">Atualizando semanas...</div>';
    try {
      const data = await loadData();
      rows = buildRows(data);
      renderSummary();
      renderRows();
      document.getElementById("pageStatus").textContent = "Dados semanais atualizados.";
    } catch (error) {
      document.getElementById("studentList").innerHTML = '<div class="empty">Não foi possível carregar os planos semanais: ' + esc(error.message || "erro desconhecido") + '.</div>';
      document.getElementById("pageStatus").textContent = "Erro ao carregar os dados semanais.";
    } finally {
      button.disabled = false;
    }
  }

  async function init() {
    const ready = await waitForResources();
    if (!ready) { document.body.classList.remove("auth-checking"); document.getElementById("pageStatus").textContent = "Não foi possível carregar a autenticação."; return; }
    const session = await Auth.getSession();
    if (!session || !session.user) { window.location.href = "/login.html?next=" + encodeURIComponent("/planos-semanais/"); return; }
    const admin = await Auth.getClient().rpc("is_teacher_admin");
    if (admin.error || admin.data !== true) { document.body.classList.remove("auth-checking"); document.getElementById("pageStatus").textContent = "Acesso negado."; return; }
    document.getElementById("content").hidden = false;
    document.body.classList.remove("auth-checking");
    await refresh();
  }

  document.getElementById("studentSearch").addEventListener("input", renderRows);
  document.getElementById("progressFilter").addEventListener("change", renderRows);
  document.getElementById("refreshPlans").addEventListener("click", refresh);
  init();
})();
