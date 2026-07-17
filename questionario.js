let currentSession = null;
let currentQuiz = null;
let currentAttempts = [];

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

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function isEnrolledProfile(profile) {
  return !!profile && (
    profile.enrolled === true ||
    profile.enrolled === "true" ||
    !!profile.enrollment_code
  );
}

function getQuizId() {
  return new URLSearchParams(window.location.search).get("id") || "";
}

function formatDateTime(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
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

function getVideoSource(rawUrl) {
  try {
    const url = new URL(rawUrl);
    const host = url.hostname.toLowerCase().replace(/^www\./, "");

    if (host === "youtu.be") {
      const videoId = url.pathname.split("/").filter(Boolean)[0];
      if (videoId) return { type: "iframe", url: "https://www.youtube-nocookie.com/embed/" + encodeURIComponent(videoId) };
    }

    if (host === "youtube.com" || host === "m.youtube.com") {
      let videoId = url.searchParams.get("v");
      if (!videoId) {
        const parts = url.pathname.split("/").filter(Boolean);
        if (parts[0] === "embed" || parts[0] === "shorts") videoId = parts[1];
      }
      if (videoId) return { type: "iframe", url: "https://www.youtube-nocookie.com/embed/" + encodeURIComponent(videoId) };
    }

    if (host === "vimeo.com" || host === "player.vimeo.com") {
      const videoId = url.pathname.split("/").filter(Boolean).find(function (part) { return /^\d+$/.test(part); });
      if (videoId) return { type: "iframe", url: "https://player.vimeo.com/video/" + videoId };
    }

    if (host === "drive.google.com") {
      const match = url.pathname.match(/\/file\/d\/([^/]+)/);
      if (match) return { type: "iframe", url: "https://drive.google.com/file/d/" + encodeURIComponent(match[1]) + "/preview" };
    }

    if (/\.(mp4|webm|ogg)(?:$|\?)/i.test(url.toString())) {
      return { type: "video", url: url.toString() };
    }

    return { type: "iframe", url: url.toString() };
  } catch (_error) {
    return null;
  }
}

function renderVideo(item) {
  const source = getVideoSource(item.url);
  if (!source) {
    return '<p class="error">O endereço deste vídeo é inválido.</p>';
  }
  if (source.type === "video") {
    return '<video class="video-frame" controls preload="metadata" src="' + escapeHtml(source.url) + '"></video>';
  }
  return '<iframe class="video-frame" src="' + escapeHtml(source.url) + '" title="' + escapeHtml(item.title || "Vídeo do questionário") + '" allow="accelerometer; autoplay; encrypted-media; picture-in-picture" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>';
}

function renderTextItem(item) {
  return '<section class="quiz-item-card text-block">' +
    (item.title ? '<h2>' + escapeHtml(item.title) + '</h2>' : '') +
    '<p>' + escapeHtml(item.content) + '</p>' +
  '</section>';
}

function renderVideoItem(item) {
  return '<section class="quiz-item-card video-block">' +
    (item.title ? '<h2>' + escapeHtml(item.title) + '</h2>' : '') +
    renderVideo(item) +
  '</section>';
}

function renderQuestionItem(item, questionNumber) {
  const options = (item.options || []).map(function (option) {
    return '<label class="answer-option">' +
      '<input type="radio" name="' + escapeHtml(item.id) + '" value="' + escapeHtml(option.id) + '" ' + (item.required !== false ? 'required' : '') + '>' +
      '<span>' + escapeHtml(option.text) + '</span>' +
    '</label>';
  }).join("");

  return '<section class="quiz-item-card question-block">' +
    '<span class="question-number">PERGUNTA ' + questionNumber + '</span>' +
    '<h2>' + escapeHtml(item.prompt) + (item.required !== false ? ' <span aria-label="obrigatória">*</span>' : '') + '</h2>' +
    '<span class="points-label">' + Number(item.points || 1) + (Number(item.points || 1) === 1 ? ' ponto' : ' pontos') + '</span>' +
    '<div class="answer-options">' + options + '</div>' +
  '</section>';
}

function renderAttemptHistory() {
  if (!currentAttempts.length) return "";
  const best = Math.max.apply(null, currentAttempts.map(function (attempt) { return Number(attempt.percentage || 0); }));
  return '<div class="card-meta">' +
    '<span class="status-pill success">Melhor resultado: ' + escapeHtml(formatPercentage(best)) + '</span>' +
    '<span class="status-pill">' + currentAttempts.length + (currentAttempts.length === 1 ? ' tentativa' : ' tentativas') + '</span>' +
  '</div>';
}

function renderQuiz() {
  const mount = document.getElementById("quizMount");
  let questionNumber = 0;
  const itemsHtml = (currentQuiz.items || []).map(function (item) {
    if (item.type === "text") return renderTextItem(item);
    if (item.type === "video") return renderVideoItem(item);
    questionNumber += 1;
    return renderQuestionItem(item, questionNumber);
  }).join("");

  mount.innerHTML =
    '<header class="quiz-page-header">' +
      '<span class="eyebrow">QUESTIONÁRIO</span>' +
      '<h1>' + escapeHtml(currentQuiz.title) + '</h1>' +
      (currentQuiz.description ? '<p>' + escapeHtml(currentQuiz.description) + '</p>' : '') +
      renderAttemptHistory() +
    '</header>' +
    '<form id="studentQuizForm">' +
      '<div class="quiz-form-items">' + itemsHtml + '</div>' +
      '<section class="quiz-panel submit-panel">' +
        '<button id="submitQuizButton" class="primary-button save-quiz-button" type="submit">ENVIAR RESPOSTAS</button>' +
        '<p id="submitMessage" class="form-message" role="status"></p>' +
      '</section>' +
    '</form>' +
    '<div id="quizResult"></div>';

  document.getElementById("studentQuizForm").addEventListener("submit", submitQuiz);
}

async function submitQuiz(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const button = document.getElementById("submitQuizButton");
  const message = document.getElementById("submitMessage");
  const formData = new FormData(form);
  const answers = {};

  (currentQuiz.items || []).forEach(function (item) {
    if (item.type !== "multiple_choice") return;
    const selected = formData.get(item.id);
    if (selected) answers[item.id] = selected;
  });

  button.disabled = true;
  button.textContent = "CORRIGINDO...";
  message.className = "form-message";
  message.textContent = "Enviando respostas e calculando sua pontuação...";

  try {
    const response = await Auth.getClient().rpc("submit_quiz_attempt", {
      target_quiz_id: currentQuiz.quiz_id,
      target_answers: answers
    });
    if (response.error) throw response.error;

    const result = response.data || {};
    form.querySelectorAll("input, button").forEach(function (element) {
      element.disabled = true;
    });
    message.textContent = "";
    document.getElementById("quizResult").innerHTML =
      '<section class="result-panel" tabindex="-1">' +
        '<span class="eyebrow">RESULTADO</span>' +
        '<h2>Questionário concluído</h2>' +
        '<div class="result-score">' + escapeHtml(formatPercentage(result.percentage)) + '</div>' +
        '<p>Você obteve <strong>' + Number(result.score) + '</strong> de <strong>' + Number(result.max_score) + '</strong> pontos.</p>' +
        '<div class="result-actions">' +
          '<button class="secondary-button" type="button" id="retryQuizButton">TENTAR NOVAMENTE</button>' +
          '<a class="link-button" href="/exercicios-diarios/">VOLTAR AO PORTAL</a>' +
        '</div>' +
      '</section>';
    document.getElementById("retryQuizButton").addEventListener("click", function () {
      window.location.reload();
    });
    document.querySelector(".result-panel").focus();
    document.querySelector(".result-panel").scrollIntoView({ behavior: "smooth", block: "center" });
  } catch (error) {
    message.className = "form-message error";
    message.textContent = error.message || "Não foi possível enviar suas respostas.";
    button.disabled = false;
    button.textContent = "ENVIAR RESPOSTAS";
  }
}

async function loadQuizData(quizId) {
  const client = Auth.getClient();
  const responses = await Promise.all([
    client.rpc("get_quiz_for_student", { target_quiz_id: quizId }),
    client.rpc("get_my_quiz_attempts", { target_quiz_id: quizId })
  ]);
  if (responses[0].error) throw responses[0].error;
  if (responses[1].error) throw responses[1].error;
  currentQuiz = responses[0].data;
  currentAttempts = responses[1].data || [];
}

function showError(message) {
  document.getElementById("quizMount").innerHTML =
    '<section class="quiz-panel"><p class="error">' + escapeHtml(message) + '</p><div class="card-actions"><a class="link-button" href="/exercicios-diarios/">VOLTAR AO PORTAL</a></div></section>';
}

async function guardQuizPage() {
  const status = document.getElementById("pageStatus");
  const ready = await waitForAuthResources();

  if (!ready) {
    status.textContent = "Não foi possível carregar a autenticação.";
    showError("Atualize a página ou limpe o cache do navegador.");
    document.body.classList.remove("auth-checking");
    return;
  }

  const quizId = getQuizId();
  if (!quizId) {
    status.textContent = "Questionário não identificado.";
    showError("O endereço deste questionário está incompleto.");
    document.body.classList.remove("auth-checking");
    return;
  }

  currentSession = await Auth.getSession();
  if (!currentSession || !currentSession.user) {
    window.location.href = "login.html?next=" + encodeURIComponent("questionario/?id=" + quizId);
    return;
  }

  const profile = await Auth.getProfile();
  if (!isEnrolledProfile(profile)) {
    status.textContent = "Acesso restrito a alunos matriculados.";
    showError("Este questionário está disponível apenas para alunos matriculados.");
    document.body.classList.remove("auth-checking");
    return;
  }

  try {
    await loadQuizData(quizId);
    document.title = currentQuiz.title + " - Teacher Flávio";
    status.textContent = "Aluno conectado: " + currentSession.user.email + ".";
    renderQuiz();
  } catch (error) {
    status.textContent = "Não foi possível carregar o questionário.";
    showError(error.message || "O questionário pode não estar publicado.");
  } finally {
    document.body.classList.remove("auth-checking");
  }
}

guardQuizPage();
