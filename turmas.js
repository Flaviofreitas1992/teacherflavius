let currentProfessorSession = null;
let currentClasses = [];

function redirectToLogin() {
  window.location.href = "login.html?next=" + encodeURIComponent("turmas.html");
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

function getClassDisplayName(classItem) {
  return String(classItem.class_name || ("Turma " + classItem.class_number));
}

function getClassTypeMeta(value) {
  if (value === "group") return { label: "GRUPO", css: "group" };
  if (value === "individual") return { label: "INDIVIDUAL", css: "individual" };
  return { label: "TIPO NÃO DEFINIDO", css: "unset" };
}

function sortClassesAlphabetically(classes) {
  return classes.slice().sort(function (firstClass, secondClass) {
    return getClassDisplayName(firstClass).localeCompare(
      getClassDisplayName(secondClass),
      "pt-BR",
      { sensitivity: "base", numeric: true }
    );
  });
}

async function loadClasses() {
  const client = Auth.getClient();
  const response = await client.rpc("get_teacher_classes_with_type");
  if (response.error) throw response.error;
  return sortClassesAlphabetically(response.data || []);
}

function renderClassCard(classItem) {
  const classNumber = classItem.class_number;
  const className = classItem.class_name || ("Turma " + classNumber);
  const studentCount = Number(classItem.student_count || 0);
  const typeMeta = getClassTypeMeta(classItem.class_type);

  return '<div class="class-card" data-class-number="' + escapeHtml(classNumber) + '">' +
    '<div class="class-card-title"><span><span class="icon">🏫</span>' + escapeHtml(className) + '</span><span class="class-type-badge ' + typeMeta.css + '">' + typeMeta.label + '</span></div>' +
    '<p class="class-meta">Alunos inscritos: ' + studentCount + '</p>' +
    '<div class="type-editor">' +
      '<label for="class-type-' + escapeHtml(classNumber) + '">Etiqueta da turma</label>' +
      '<select id="class-type-' + escapeHtml(classNumber) + '" class="class-type-select" data-class-type-select="' + escapeHtml(classNumber) + '">' +
        '<option value=""' + (!classItem.class_type ? ' selected' : '') + '>Selecione</option>' +
        '<option value="group"' + (classItem.class_type === 'group' ? ' selected' : '') + '>GRUPO</option>' +
        '<option value="individual"' + (classItem.class_type === 'individual' ? ' selected' : '') + '>INDIVIDUAL</option>' +
      '</select>' +
      '<button class="type-save-button" type="button" data-save-class-type="' + escapeHtml(classNumber) + '">SALVAR ETIQUETA</button>' +
    '</div>' +
    '<div class="class-actions">' +
      '<a class="open-class-button" href="turma.html?id=' + encodeURIComponent(classNumber) + '">ABRIR TURMA</a>' +
      '<button class="remove-class-button" type="button" data-class-number="' + escapeHtml(classNumber) + '" data-class-name="' + escapeHtml(className) + '">EXCLUIR TURMA</button>' +
    '</div>' +
  '</div>';
}

function renderClassesFromState() {
  const grid = document.getElementById("classesGrid");
  if (!currentClasses.length) {
    grid.className = "empty";
    grid.textContent = "Nenhuma turma criada ainda.";
    return;
  }

  grid.className = "menu-grid";
  grid.innerHTML = currentClasses.map(renderClassCard).join("");
  attachClassButtons();
}

async function renderClasses() {
  const grid = document.getElementById("classesGrid");
  try {
    currentClasses = await loadClasses();
    renderClassesFromState();
  } catch (error) {
    grid.className = "error";
    grid.textContent = "Não foi possível carregar as turmas: " + (error.message || "erro desconhecido") + ".";
  }
}

async function createClass(event) {
  event.preventDefault();
  const message = document.getElementById("classMessage");
  const input = document.getElementById("className");
  const typeSelect = document.getElementById("classType");
  const className = input.value.trim();
  const classType = typeSelect.value;

  if (!classType) {
    message.className = "error";
    message.textContent = "Selecione se a turma é GRUPO ou INDIVIDUAL.";
    return;
  }

  message.className = "empty";
  message.textContent = "Criando turma...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("create_teacher_class_with_type", {
      target_class_name: className || null,
      target_class_type: classType
    });
    if (response.error) throw response.error;
    input.value = "";
    typeSelect.value = "";
    message.className = "empty";
    message.textContent = "Turma criada com a etiqueta definida.";
    await renderClasses();
  } catch (error) {
    message.className = "error";
    message.textContent = "Não foi possível criar a turma: " + (error.message || "erro desconhecido") + ".";
  }
}

async function saveClassType(classNumber, button) {
  const select = document.querySelector('[data-class-type-select="' + CSS.escape(String(classNumber)) + '"]');
  const classType = select ? select.value : "";
  if (!classType) {
    alert("Selecione GRUPO ou INDIVIDUAL antes de salvar.");
    return;
  }

  button.disabled = true;
  button.textContent = "SALVANDO...";
  try {
    const response = await Auth.getClient().rpc("set_teacher_class_type", {
      target_class_number: Number(classNumber),
      target_class_type: classType
    });
    if (response.error) throw response.error;
    await renderClasses();
  } catch (error) {
    alert("Não foi possível salvar a etiqueta: " + (error.message || "erro desconhecido") + ".");
    button.disabled = false;
    button.textContent = "SALVAR ETIQUETA";
  }
}

async function deleteClass(classNumber, className, button) {
  const confirmed = window.confirm("Excluir " + className + "? Isso remove os alunos da turma e os links cadastrados para ela. Os registros de frequência já salvos permanecem no histórico geral dos alunos.");
  if (!confirmed) return;

  button.disabled = true;
  button.textContent = "EXCLUINDO...";

  try {
    const client = Auth.getClient();
    const response = await client.rpc("delete_teacher_class", { target_class_number: Number(classNumber) });
    if (response.error) throw response.error;
    await renderClasses();
  } catch (error) {
    alert("Não foi possível excluir a turma: " + (error.message || "erro desconhecido") + ".");
    button.disabled = false;
    button.textContent = "EXCLUIR TURMA";
  }
}

function attachClassButtons() {
  document.querySelectorAll(".remove-class-button").forEach(function (button) {
    button.addEventListener("click", function () {
      deleteClass(button.dataset.classNumber, button.dataset.className, button);
    });
  });

  document.querySelectorAll("[data-save-class-type]").forEach(function (button) {
    button.addEventListener("click", function () {
      saveClassType(button.dataset.saveClassType, button);
    });
  });
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
  await renderClasses();
}

const createClassForm = document.getElementById("createClassForm");
if (createClassForm) createClassForm.addEventListener("submit", createClass);

guardPage();
