let currentSession = null;

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("area_do_estudante.html");
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForAuthResources() {
  for (let i = 0; i < 10; i++) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function extractActivityNumber(title) {
  const match = String(title || "").match(/ATIVIDADE\s+(\d+)/i);
  return match ? Number(match[1]) : Number.MAX_SAFE_INTEGER;
}

function closeOverdueModal() {
  const modal = document.getElementById("overdueModal");
  if (modal) modal.hidden = true;
}

function bindOverdueModal() {
  const modal = document.getElementById("overdueModal");
  const closeButton = document.getElementById("overdueClose");

  if (closeButton) {
    closeButton.addEventListener("click", closeOverdueModal);
  }

  if (modal) {
    modal.addEventListener("click", function (event) {
      if (event.target === modal) closeOverdueModal();
    });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") closeOverdueModal();
  });
}

async function guardStudentArea() {
  const status = document.getElementById("loginStatus");
  const resourcesReady = await waitForAuthResources();

  if (!resourcesReady) {
    document.body.classList.remove("auth-checking");
    if (status) {
      status.hidden = false;
      status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache do navegador.";
    }
    return false;
  }

  currentSession = await Auth.getSession();

  if (!currentSession || !currentSession.user) {
    redirectToLogin();
    return false;
  }

  document.body.classList.remove("auth-checking");
  return true;
}

async function loadPublishedExercises() {
  const client = Auth.getClient();
  const response = await client.rpc("get_public_teacher_exercises");
  if (response.error) throw response.error;

  return (response.data || []).map(function (item) {
    return {
      id: item.exercise_id,
      title: item.exercise_title,
      url: item.exercise_url
    };
  });
}

async function loadStudentCompletions() {
  const client = Auth.getClient();
  const response = await client
    .from("daily_exercise_completion")
    .select("exercise_id, completed")
    .eq("user_id", currentSession.user.id);

  if (response.error) throw response.error;
  return response.data || [];
}

async function showOverdueActivityIfNeeded() {
  const modal = document.getElementById("overdueModal");
  const link = document.getElementById("overdueActivityLink");
  if (!modal || !link) return;

  try {
    const results = await Promise.all([
      loadPublishedExercises(),
      loadStudentCompletions()
    ]);

    const exercises = results[0];
    const completions = results[1];
    const completedMap = new Map();

    completions.forEach(function (row) {
      completedMap.set(row.exercise_id, row.completed === true);
    });

    const pending = exercises
      .filter(function (exercise) {
        return exercise.id && completedMap.get(exercise.id) !== true;
      })
      .sort(function (a, b) {
        const numberDiff = extractActivityNumber(a.title) - extractActivityNumber(b.title);
        return numberDiff !== 0 ? numberDiff : String(a.title || "").localeCompare(String(b.title || ""), "pt-BR");
      });

    if (!pending.length) {
      modal.hidden = true;
      return;
    }

    const overdueExercise = pending.find(function (exercise) {
      return !!exercise.url;
    }) || pending[0];

    link.textContent = overdueExercise.title || "Abrir atividade pendente";
    link.href = overdueExercise.url || "/exercicios-diarios/";
    modal.hidden = false;
  } catch (error) {
    console.error("Não foi possível verificar atividades atrasadas:", error);
    modal.hidden = true;
  }
}

async function updateStatus() {
  const isAllowed = await guardStudentArea();
  if (!isAllowed) return;

  const status = document.getElementById("loginStatus");
  if (status) {
    status.textContent = "";
    status.hidden = true;
  }

  await showOverdueActivityIfNeeded();
}

bindOverdueModal();
updateStatus();
