let currentProfessorSession = null;
let builderItems = [];
let editingQuizId = null;
let teacherQuizzes = [];
let teacherResults = [];

function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}

async function waitForAuthResources() {
  for (let index = 0; index < 10; index += 1) {
    if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
    await sleep(150);
  }
  return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
}

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("questionarios_admin.html");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function uniqueId(prefix) {
  if (window.crypto && typeof window.crypto.randomUUID === "function") {
    return prefix + "-" + window.crypto.randomUUID();
  }
  return prefix + "-" + Date.now() + "-" + Math.random().toString(36).slice(2);
}

function createOption(text, correct) {
  return {
    id: uniqueId("option"),
    text: text || "",
    correct: correct === true
  };
}

function createBuilderItem(type) {
  if (type === "text") {
    return { id: uniqueId("text"), type: "text", title: "", content: "" };
  }
  if (type === "video") {
    return { id: uniqueId("video"), type: "video", title: "", url: "" };
  }
  return {
    id: uniqueId("question"),
    type: "multiple_choice",
    prompt: "",
    points: 1,
    required: true,
    options: [
      createOption("", true),
      createOption("", false)
    ]
  };
}

function blockLabel(type) {
  if (type === "text") return "BLOCO DE TEXTO";
  if (type === "video") return "BLOCO DE VÍDEO";
  return "PERGUNTA DE MÚLTIPLA ESCOLHA";
}

function renderBlockActions(item, index) {
  return '<div class="block-actions">' +
    '<button class="block-action" type="button" data-action="move-up" data-item-id="' + escapeHtml(item.id) + '" ' + (index === 0 ? 'disabled' : '') + '>↑</button>' +
    '<button class="block-action" type="button" data-action="move-down" data-item-id="' + escapeHtml(item.id) + '" ' + (index === builderItems.length - 1 ? 'disabled' : '') + '>↓</button>' +
    '<button class="block-action remove" type="button" data-action="remove-block" data-item-id="' + escapeHtml(item.id) + '">REMOVER</button>' +
  '</div>';
}

function renderTextBlock(item, index) {
  return '<article class="builder-block" data-item-id="' + escapeHtml(item.id) + '">' +
    '<div class="block-heading"><strong>' + (index + 1) + '. ' + blockLabel(item.type) + '</strong>' + renderBlockActions(item, index) + '</div>' +
    '<div class="block-fields">' +
      '<label class="block-field"><span>Título do texto (opcional)</span><input type="text" maxlength="200" data-item-id="' + escapeHtml(item.id) + '" data-field="title" value="' + escapeHtml(item.title) + '" placeholder="Ex.: Leia antes de responder"></label>' +
      '<label class="block-field"><span>Texto</span><textarea rows="5" maxlength="5000" data-item-id="' + escapeHtml(item.id) + '" data-field="content" placeholder="Digite o conteúdo que o aluno deverá ler.">' + escapeHtml(item.content) + '</textarea></label>' +
    '</div>' +
  '</article>';
}

function renderVideoBlock(item, index) {
  return '<article class="builder-block" data-item-id="' + escapeHtml(item.id) + '">' +
    '<div class="block-heading"><strong>' + (index + 1) + '. ' + blockLabel(item.type) + '</strong>' + renderBlockActions(item, index) + '</div>' +
    '<div class="block-fields">' +
      '<label class="block-field"><span>Título ou instrução (opcional)</span><input type="text" maxlength="200" data-item-id="' + escapeHtml(item.id) + '" data-field="title" value="' + escapeHtml(item.title) + '" placeholder="Ex.: Assista ao vídeo e responda"></label>' +
      '<label class="block-field"><span>URL do vídeo</span><input type="url" data-item-id="' + escapeHtml(item.id) + '" data-field="url" value="' + escapeHtml(item.url) + '" placeholder="YouTube, Vimeo, Google Drive ou arquivo MP4"></label>' +
      '<p class="block-help">O vídeo será incorporado à página. Links do YouTube, Vimeo, Google Drive e arquivos diretos de vídeo oferecem a melhor compatibilidade.</p>' +
    '</div>' +
  '</article>';
}

function renderQuestionBlock(item, index) {
  const options = (item.options || []).map(function (option, optionIndex) {
    return '<div class="option-row">' +
      '<label title="Marcar como resposta correta"><input type="radio" name="correct-' + escapeHtml(item.id) + '" data-action="correct-option" data-item-id="' + escapeHtml(item.id) + '" data-option-id="' + escapeHtml(option.id) + '" ' + (option.correct ? 'checked' : '') + '><span class="correct-label">CORRETA</span></label>' +
      '<input type="text" maxlength="500" data-item-id="' + escapeHtml(item.id) + '" data-option-id="' + escapeHtml(option.id) + '" data-option-field="text" value="' + escapeHtml(option.text) + '" placeholder="Alternativa ' + (optionIndex + 1) + '">' +
      '<button class="option-action remove" type="button" data-action="remove-option" data-item-id="' + escapeHtml(item.id) + '" data-option-id="' + escapeHtml(option.id) + '">REMOVER</button>' +
    '</div>';
  }).join("");

  return '<article class="builder-block" data-item-id="' + escapeHtml(item.id) + '">' +
    '<div class="block-heading"><strong>' + (index + 1) + '. ' + blockLabel(item.type) + '</strong>' + renderBlockActions(item, index) + '</div>' +
    '<div class="block-fields">' +
      '<label class="block-field"><span>Enunciado</span><textarea rows="3" maxlength="2000" data-item-id="' + escapeHtml(item.id) + '" data-field="prompt" placeholder="Digite a pergunta.">' + escapeHtml(item.prompt) + '</textarea></label>' +
      '<div class="question-settings">' +
        '<label class="block-field"><span>Pontos</span><input type="number" min="1" max="100" data-item-id="' + escapeHtml(item.id) + '" data-field="points" value="' + escapeHtml(item.points) + '"></label>' +
        '<label class="required-toggle"><input type="checkbox" data-item-id="' + escapeHtml(item.id) + '" data-field="required" ' + (item.required !== false ? 'checked' : '') + '><span>Resposta obrigatória</span></label>' +
      '</div>' +
      '<div><span class="block-help">Marque o círculo da alternativa correta.</span><div class="options-list">' + options + '</div></div>' +
      '<button class="block-action add-option-button" type="button" data-action="add-option" data-item-id="' + escapeHtml(item.id) + '">＋ ADICIONAR ALTERNATIVA</button>' +
    '</div>' +
  '</article>';
}

function renderBuilder() {
  const container = document.getElementById("builderItems");
  if (!builderItems.length) {
    container.innerHTML = '<div class="builder-empty">Use os botões acima para adicionar texto, vídeo ou uma pergunta.</div>';
    return;
  }

  container.innerHTML = builderItems.map(function (item, index) {
    if (item.type === "text") return renderTextBlock(item, index);
    if (item.type === "video") return renderVideoBlock(item, index);
    return renderQuestionBlock(item, index);
  }).join("");
}

function findBuilderItem(itemId) {
  return builderItems.find(function (item) { return item.id === itemId; }) || null;
}

function handleBuilderValue(event) {
  const target = event.target;
  const item = findBuilderItem(target.dataset.itemId);
  if (!item) return;

  if (target.dataset.optionField && target.dataset.optionId) {
    const option = (item.options || []).find(function (entry) { return entry.id === target.dataset.optionId; });
    if (option) option[target.dataset.optionField] = target.value;
    return;
  }

  if (target.dataset.action === "correct-option" && target.dataset.optionId) {
    item.options.forEach(function (option) {
      option.correct = option.id === target.dataset.optionId;
    });
    return;
  }

  if (!target.dataset.field) return;
  if (target.dataset.field === "required") {
    item.required = target.checked;
  } else if (target.dataset.field === "points") {
    item.points = Number(target.value);
  } else {
    item[target.dataset.field] = target.value;
  }
}

function handleBuilderAction(event) {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const itemIndex = builderItems.findIndex(function (item) { return item.id === button.dataset.itemId; });
  if (itemIndex < 0) return;
  const item = builderItems[itemIndex];
  const action = button.dataset.action;

  if (action === "remove-block") {
    builderItems.splice(itemIndex, 1);
  } else if (action === "move-up" && itemIndex > 0) {
    const previous = builderItems[itemIndex - 1];
    builderItems[itemIndex - 1] = item;
    builderItems[itemIndex] = previous;
  } else if (action === "move-down" && itemIndex < builderItems.length - 1) {
    const next = builderItems[itemIndex + 1];
    builderItems[itemIndex + 1] = item;
    builderItems[itemIndex] = next;
  } else if (action === "add-option") {
    item.options.push(createOption("", false));
  } else if (action === "remove-option") {
    if (item.options.length <= 2) {
      window.alert("Cada pergunta precisa de pelo menos duas alternativas.");
      return;
    }
    const removed = item.options.find(function (option) { return option.id === button.dataset.optionId; });
    item.options = item.options.filter(function (option) { return option.id !== button.dataset.optionId; });
    if (removed && removed.correct && item.options.length) item.options[0].correct = true;
  }

  renderBuilder();
}

function parseQuizDefinition(value) {
  if (Array.isArray(value)) return value;
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_error) {
    return [];
  }
}

function validateVideoUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:";
  } catch (_error) {
    return false;
  }
}

function buildDefinition() {
  if (!builderItems.length) throw new Error("Adicione conteúdo ao questionário.");
  let questionCount = 0;

  const definition = builderItems.map(function (item) {
    if (item.type === "text") {
      const content = String(item.content || "").trim();
      if (!content) throw new Error("Preencha todos os blocos de texto.");
      return { id: item.id, type: "text", title: String(item.title || "").trim(), content: content };
    }

    if (item.type === "video") {
      const url = String(item.url || "").trim();
      if (!validateVideoUrl(url)) throw new Error("Informe uma URL válida em todos os blocos de vídeo.");
      return { id: item.id, type: "video", title: String(item.title || "").trim(), url: url };
    }

    questionCount += 1;
    const prompt = String(item.prompt || "").trim();
    const points = Number(item.points);
    if (!prompt) throw new Error("Preencha o enunciado de todas as perguntas.");
    if (!Number.isInteger(points) || points < 1 || points > 100) {
      throw new Error("Cada pergunta deve valer entre 1 e 100 pontos.");
    }
    if (!Array.isArray(item.options) || item.options.length < 2) {
      throw new Error("Cada pergunta precisa de pelo menos duas alternativas.");
    }

    const options = item.options.map(function (option) {
      const text = String(option.text || "").trim();
      if (!text) throw new Error("Preencha o texto de todas as alternativas.");
      return { id: option.id, text: text, correct: option.correct === true };
    });

    if (options.filter(function (option) { return option.correct; }).length !== 1) {
      throw new Error("Marque exatamente uma alternativa correta em cada pergunta.");
    }

    return {
      id: item.id,
      type: "multiple_choice",
      prompt: prompt,
      points: points,
      required: item.required !== false,
      options: options
    };
  });

  if (!questionCount) throw new Error("Adicione pelo menos uma pergunta de múltipla escolha.");
  return definition;
}

function resetBuilder(message) {
  editingQuizId = null;
  builderItems = [createBuilderItem("multiple_choice")];
  document.getElementById("quizForm").reset();
  document.getElementById("builderTitle").textContent = "Novo questionário";
  document.getElementById("saveQuizButton").textContent = "SALVAR QUESTIONÁRIO";
  document.getElementById("cancelEditButton").hidden = true;
  renderBuilder();

  const formMessage = document.getElementById("quizFormMessage");
  formMessage.className = message ? "form-message success" : "form-message";
  formMessage.textContent = message || "";
}

function formatDateTime(value) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat("pt-BR", {
    day: "2-digit", month: "2-digit", year: "numeric",
    hour: "2-digit", minute: "2-digit", timeZone: "America/Sao_Paulo"
  }).format(date);
}

function formatPercentage(value) {
  return Number(value || 0).toLocaleString("pt-BR", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  }) + "%";
}

async function loadTeacherData() {
  const client = Auth.getClient();
  const responses = await Promise.all([
    client.rpc("get_teacher_quizzes"),
    client.rpc("get_teacher_quiz_results")
  ]);
  if (responses[0].error) throw responses[0].error;
  if (responses[1].error) throw responses[1].error;
  teacherQuizzes = responses[0].data || [];
  teacherResults = responses[1].data || [];
}

function renderTeacherQuizzes() {
  const container = document.getElementById("teacherQuizzes");
  if (!teacherQuizzes.length) {
    container.innerHTML = '<p class="empty">Nenhum questionário criado ainda.</p>';
    return;
  }

  container.innerHTML = teacherQuizzes.map(function (quiz) {
    const published = quiz.is_published === true;
    return '<article class="manage-quiz-card">' +
      '<h3>' + escapeHtml(quiz.quiz_title) + '</h3>' +
      (quiz.quiz_description ? '<p>' + escapeHtml(quiz.quiz_description) + '</p>' : '') +
      '<div class="card-meta">' +
        '<span class="status-pill ' + (published ? 'success' : 'warning') + '">' + (published ? 'Publicado' : 'Rascunho') + '</span>' +
        '<span class="status-pill">' + Number(quiz.question_count || 0) + ' perguntas</span>' +
        '<span class="status-pill">' + Number(quiz.total_points || 0) + ' pontos</span>' +
        '<span class="status-pill">' + Number(quiz.attempt_count || 0) + ' respostas</span>' +
      '</div>' +
      '<p><strong>Publicação:</strong> ' + escapeHtml(formatDateTime(quiz.published_at)) + '</p>' +
      '<div class="card-actions">' +
        '<button class="secondary-button" type="button" data-quiz-action="edit" data-quiz-id="' + escapeHtml(quiz.quiz_id) + '">EDITAR</button>' +
        '<button class="secondary-button" type="button" data-quiz-action="publish" data-published="' + (published ? 'true' : 'false') + '" data-quiz-id="' + escapeHtml(quiz.quiz_id) + '">' + (published ? 'DESPUBLICAR' : 'PUBLICAR') + '</button>' +
        (published ? '<a class="link-button" href="/questionario/?id=' + encodeURIComponent(quiz.quiz_id) + '" target="_blank" rel="noopener noreferrer">VISUALIZAR</a>' : '') +
        '<button class="danger-button" type="button" data-quiz-action="archive" data-quiz-id="' + escapeHtml(quiz.quiz_id) + '" data-quiz-title="' + escapeHtml(quiz.quiz_title) + '">ARQUIVAR</button>' +
      '</div>' +
    '</article>';
  }).join("");
}

function renderTeacherResults() {
  const container = document.getElementById("teacherQuizResults");
  if (!teacherResults.length) {
    container.innerHTML = '<p class="empty">Nenhum aluno respondeu aos questionários ainda.</p>';
    return;
  }

  container.innerHTML = teacherResults.map(function (result) {
    return '<article class="result-card">' +
      '<h3>' + escapeHtml(result.student_name || "Aluno") + '</h3>' +
      '<p><strong>E-mail:</strong> ' + escapeHtml(result.student_email || "Não informado") + '</p>' +
      '<p><strong>Questionário:</strong> ' + escapeHtml(result.quiz_title) + '</p>' +
      '<div class="card-meta">' +
        '<span class="status-pill success">' + Number(result.score) + ' de ' + Number(result.max_score) + ' pontos</span>' +
        '<span class="status-pill">' + escapeHtml(formatPercentage(result.percentage)) + '</span>' +
      '</div>' +
      '<p><strong>Enviado em:</strong> ' + escapeHtml(formatDateTime(result.submitted_at)) + '</p>' +
    '</article>';
  }).join("");
}

async function refreshAdminData() {
  document.getElementById("teacherQuizzes").innerHTML = '<p class="empty">Carregando questionários...</p>';
  document.getElementById("teacherQuizResults").innerHTML = '<p class="empty">Carregando resultados...</p>';
  await loadTeacherData();
  renderTeacherQuizzes();
  renderTeacherResults();
}

async function saveQuiz(event) {
  event.preventDefault();
  const button = document.getElementById("saveQuizButton");
  const message = document.getElementById("quizFormMessage");

  try {
    const title = document.getElementById("quizTitle").value.trim();
    if (!title) throw new Error("Informe o título do questionário.");
    const definition = buildDefinition();

    button.disabled = true;
    button.textContent = "SALVANDO...";
    message.className = "form-message";
    message.textContent = "Salvando questionário...";

    const response = await Auth.getClient().rpc("save_quiz", {
      target_quiz_id: editingQuizId,
      target_title: title,
      target_description: document.getElementById("quizDescription").value.trim() || null,
      target_definition: definition,
      target_publish: document.getElementById("publishQuiz").checked
    });
    if (response.error) throw response.error;

    const successMessage = editingQuizId
      ? "Questionário atualizado com sucesso."
      : "Questionário criado com sucesso.";
    resetBuilder(successMessage);
    await refreshAdminData();
  } catch (error) {
    message.className = "form-message error";
    message.textContent = error.message || "Não foi possível salvar o questionário.";
  } finally {
    button.disabled = false;
    button.textContent = editingQuizId ? "ATUALIZAR QUESTIONÁRIO" : "SALVAR QUESTIONÁRIO";
  }
}

function startEditingQuiz(quizId) {
  const quiz = teacherQuizzes.find(function (item) { return item.quiz_id === quizId; });
  if (!quiz) return;

  editingQuizId = quiz.quiz_id;
  builderItems = JSON.parse(JSON.stringify(parseQuizDefinition(quiz.quiz_definition)));
  document.getElementById("quizTitle").value = quiz.quiz_title || "";
  document.getElementById("quizDescription").value = quiz.quiz_description || "";
  document.getElementById("publishQuiz").checked = quiz.is_published === true;
  document.getElementById("builderTitle").textContent = "Editar questionário";
  document.getElementById("saveQuizButton").textContent = "ATUALIZAR QUESTIONÁRIO";
  document.getElementById("cancelEditButton").hidden = false;
  document.getElementById("quizFormMessage").textContent = "";
  renderBuilder();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function toggleQuizPublication(quizId, currentlyPublished, button) {
  button.disabled = true;
  try {
    const response = await Auth.getClient().rpc("set_quiz_published", {
      target_quiz_id: quizId,
      target_published: !currentlyPublished
    });
    if (response.error) throw response.error;
    await refreshAdminData();
  } catch (error) {
    window.alert("Não foi possível alterar a publicação: " + (error.message || "tente novamente."));
    button.disabled = false;
  }
}

async function archiveQuiz(quizId, quizTitle, button) {
  const confirmed = window.confirm(
    'Arquivar "' + quizTitle + '"? Ele deixará de aparecer para os alunos, mas as pontuações serão preservadas.'
  );
  if (!confirmed) return;

  button.disabled = true;
  try {
    const response = await Auth.getClient().rpc("archive_quiz", { target_quiz_id: quizId });
    if (response.error) throw response.error;
    if (editingQuizId === quizId) resetBuilder();
    await refreshAdminData();
  } catch (error) {
    window.alert("Não foi possível arquivar: " + (error.message || "tente novamente."));
    button.disabled = false;
  }
}

document.querySelectorAll("[data-add-type]").forEach(function (button) {
  button.addEventListener("click", function () {
    builderItems.push(createBuilderItem(button.dataset.addType));
    renderBuilder();
  });
});

document.getElementById("builderItems").addEventListener("input", handleBuilderValue);
document.getElementById("builderItems").addEventListener("change", handleBuilderValue);
document.getElementById("builderItems").addEventListener("click", handleBuilderAction);
document.getElementById("quizForm").addEventListener("submit", saveQuiz);
document.getElementById("cancelEditButton").addEventListener("click", function () { resetBuilder(); });
document.getElementById("refreshAdminButton").addEventListener("click", function () {
  refreshAdminData().catch(function (error) {
    document.getElementById("adminStatus").textContent = "Não foi possível atualizar: " + (error.message || "tente novamente.");
  });
});

document.getElementById("teacherQuizzes").addEventListener("click", function (event) {
  const target = event.target.closest("[data-quiz-action]");
  if (!target) return;
  const action = target.dataset.quizAction;
  if (action === "edit") {
    startEditingQuiz(target.dataset.quizId);
  } else if (action === "publish") {
    toggleQuizPublication(target.dataset.quizId, target.dataset.published === "true", target);
  } else if (action === "archive") {
    archiveQuiz(target.dataset.quizId, target.dataset.quizTitle, target);
  }
});

async function guardAdminPage() {
  const status = document.getElementById("adminStatus");
  const ready = await waitForAuthResources();

  if (!ready) {
    status.textContent = "Não foi possível carregar a autenticação. Atualize a página ou limpe o cache.";
    document.body.classList.remove("auth-checking");
    return;
  }

  currentProfessorSession = await Auth.getSession();
  if (!currentProfessorSession || !currentProfessorSession.user) {
    redirectToLogin();
    return;
  }

  const adminResponse = await Auth.getClient().rpc("is_teacher_admin");
  if (adminResponse.error || adminResponse.data !== true) {
    status.textContent = "Acesso negado. Esta página é exclusiva do professor.";
    document.getElementById("quizForm").hidden = true;
    document.body.classList.remove("auth-checking");
    return;
  }

  status.textContent = "Professor autenticado: " + currentProfessorSession.user.email + ".";
  document.body.classList.remove("auth-checking");
  resetBuilder();

  try {
    await refreshAdminData();
  } catch (error) {
    document.getElementById("teacherQuizzes").innerHTML = '<p class="error">' + escapeHtml(error.message || "Não foi possível carregar os questionários.") + '</p>';
    document.getElementById("teacherQuizResults").innerHTML = '<p class="error">Não foi possível carregar os resultados.</p>';
  }
}

guardAdminPage();
