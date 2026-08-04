(function () {
  "use strict";

  const state = {
    client: null,
    user: null,
    isTeacher: false,
    decks: [],
    students: [],
    editingDeckId: null,
    editingOwnerId: null,
    studyDeckId: null,
    studyCards: [],
    studyIndex: 0,
    studyGrades: new Map(),
    answerChecked: false
  };

  const elements = {};

  function cacheElements() {
    [
      "loginStatus", "flashcardMessage", "libraryView", "editorView", "studyView",
      "libraryTitle", "libraryLead", "teacherDirectorySection", "studentDirectory",
      "studentSearch", "ownDeckSection", "myDecks", "newDeckButton", "cancelEditorButton",
      "deckForm", "deckTitle", "deckDescription", "deckOwnerField", "deckOwner",
      "cardsEditor", "cardCount", "addCardButton", "saveDeckButton", "editorTitle",
      "cardRowTemplate", "studyTitle", "studyProgress", "studyScore", "progressBar",
      "studyWord", "translationAnswer", "checkAnswerButton", "answerFeedback",
      "answerResult", "expectedTranslation", "previousCardButton", "nextCardButton",
      "shuffleButton", "leaveStudyButton", "studyContent", "studySummary", "summaryText",
      "restartStudyButton", "finishStudyButton"
    ].forEach(function (id) { elements[id] = document.getElementById(id); });
  }

  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  async function waitForAuthResources() {
    for (let attempt = 0; attempt < 12; attempt += 1) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
  }

  function redirectToLogin() {
    window.location.href = "/login/?next=" + encodeURIComponent("/flashcards/");
  }

  function showMessage(text, type) {
    elements.flashcardMessage.textContent = text;
    elements.flashcardMessage.className = "message" + (type ? " " + type : "");
    elements.flashcardMessage.hidden = false;
    elements.flashcardMessage.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }

  function clearMessage() {
    elements.flashcardMessage.hidden = true;
    elements.flashcardMessage.textContent = "";
    elements.flashcardMessage.className = "message";
  }

  function errorText(error, fallback) {
    const message = error && error.message ? error.message : "";
    if (/save_flashcard_deck|flashcard_decks|flashcards/i.test(message) && /not find|schema cache|does not exist/i.test(message)) {
      return "O banco de flashcards ainda não foi configurado. Execute o arquivo supabase_flashcards.sql no Supabase.";
    }
    return message || fallback;
  }

  function setView(name) {
    elements.libraryView.hidden = name !== "library";
    elements.editorView.hidden = name !== "editor";
    elements.studyView.hidden = name !== "study";
    clearMessage();
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function deckCardCount(deck) {
    const relation = deck && deck.flashcards;
    return Array.isArray(relation) && relation[0] ? Number(relation[0].count || 0) : 0;
  }

  function canManageDeck(deck) {
    return !!deck && (deck.owner_id === state.user.id || state.isTeacher);
  }

  function studentDisplayName(student) {
    return student && student.name ? student.name : student && student.email ? student.email : "Aluno";
  }

  function createActionButton(label, className, action, deckId) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "button " + className;
    button.textContent = label;
    button.dataset.action = action;
    button.dataset.deckId = deckId;
    return button;
  }

  function createDeckCard(deck) {
    const article = document.createElement("article");
    article.className = "deck-card";

    const top = document.createElement("div");
    top.className = "deck-card-top";
    const title = document.createElement("h4");
    title.textContent = deck.title;
    top.appendChild(title);

    if (canManageDeck(deck)) {
      const deleteButton = document.createElement("button");
      deleteButton.type = "button";
      deleteButton.className = "icon-button";
      deleteButton.textContent = "🗑";
      deleteButton.setAttribute("aria-label", "Excluir o conjunto " + deck.title);
      deleteButton.dataset.action = "delete";
      deleteButton.dataset.deckId = deck.id;
      top.appendChild(deleteButton);
    }
    article.appendChild(top);

    if (deck.description) {
      const description = document.createElement("p");
      description.className = "deck-description";
      description.textContent = deck.description;
      article.appendChild(description);
    }

    const count = deckCardCount(deck);
    const meta = document.createElement("p");
    meta.className = "deck-meta";
    meta.textContent = count + (count === 1 ? " cartão" : " cartões");
    article.appendChild(meta);

    const actions = document.createElement("div");
    actions.className = "deck-actions";
    const studyButton = createActionButton("ESTUDAR", "button-primary", "study", deck.id);
    studyButton.disabled = count === 0;
    actions.appendChild(studyButton);
    if (canManageDeck(deck)) {
      actions.appendChild(createActionButton("EDITAR", "button-secondary", "edit", deck.id));
    }
    article.appendChild(actions);
    return article;
  }

  function renderEmpty(container, text) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = text;
    container.replaceChildren(empty);
  }

  function createStudentGroup(student) {
    const decks = state.decks.filter(function (deck) { return deck.owner_id === student.user_id; });
    const section = document.createElement("section");
    section.className = "student-group";

    const header = document.createElement("div");
    header.className = "student-group-header";
    const identity = document.createElement("div");
    identity.className = "student-identity";
    const name = document.createElement("h4");
    name.textContent = studentDisplayName(student);
    const email = document.createElement("p");
    email.textContent = student.email || "E-mail não informado";
    const count = document.createElement("span");
    count.className = "student-deck-count";
    count.textContent = decks.length + (decks.length === 1 ? " conjunto" : " conjuntos");
    identity.append(name, email, count);

    const addButton = document.createElement("button");
    addButton.type = "button";
    addButton.className = "button button-secondary";
    addButton.textContent = "+ NOVO CONJUNTO";
    addButton.dataset.action = "new-for-student";
    addButton.dataset.ownerId = student.user_id;
    header.append(identity, addButton);
    section.appendChild(header);

    const grid = document.createElement("div");
    grid.className = "deck-grid";
    if (decks.length) {
      grid.replaceChildren.apply(grid, decks.map(createDeckCard));
    } else {
      renderEmpty(grid, "Este aluno ainda não criou nenhum conjunto.");
    }
    section.appendChild(grid);
    return section;
  }

  function renderTeacherDirectory() {
    const term = String(elements.studentSearch.value || "").trim().toLocaleLowerCase("pt-BR");
    const filtered = state.students.filter(function (student) {
      return !term || (student.name || "").toLocaleLowerCase("pt-BR").includes(term)
        || (student.email || "").toLocaleLowerCase("pt-BR").includes(term);
    });

    if (!filtered.length) {
      renderEmpty(elements.studentDirectory, term ? "Nenhum aluno encontrado." : "Nenhum aluno cadastrado.");
      return;
    }
    elements.studentDirectory.replaceChildren.apply(elements.studentDirectory, filtered.map(createStudentGroup));
  }

  function renderDecks() {
    if (state.isTeacher) {
      elements.teacherDirectorySection.hidden = false;
      elements.ownDeckSection.hidden = true;
      renderTeacherDirectory();
      return;
    }

    elements.teacherDirectorySection.hidden = true;
    elements.ownDeckSection.hidden = false;
    const ownDecks = state.decks.filter(function (deck) { return deck.owner_id === state.user.id; });
    if (ownDecks.length) {
      elements.myDecks.replaceChildren.apply(elements.myDecks, ownDecks.map(createDeckCard));
    } else {
      renderEmpty(elements.myDecks, "Você ainda não criou nenhum conjunto. Clique em “Novo conjunto” para começar.");
    }
  }

  function isUuid(value) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(String(value || ""));
  }

  async function loadStudents() {
    if (!state.isTeacher) return;
    const response = await state.client.rpc("get_teacher_students");
    if (response.error) throw response.error;
    const uniqueStudents = new Map();
    (response.data || []).forEach(function (student) {
      if (isUuid(student.user_id) && student.user_id !== state.user.id && !uniqueStudents.has(student.user_id)) {
        uniqueStudents.set(student.user_id, student);
      }
    });
    state.students = Array.from(uniqueStudents.values()).sort(function (a, b) {
      return studentDisplayName(a).localeCompare(studentDisplayName(b), "pt-BR");
    });
    populateStudentSelect();
  }

  function populateStudentSelect() {
    const placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.textContent = "Selecione um aluno";
    const options = state.students.map(function (student) {
      const option = document.createElement("option");
      option.value = student.user_id;
      option.textContent = studentDisplayName(student) + (student.email ? " — " + student.email : "");
      return option;
    });
    elements.deckOwner.replaceChildren(placeholder, ...options);
  }

  async function loadDecks() {
    elements.myDecks.innerHTML = '<div class="empty-state">Carregando seus conjuntos...</div>';
    const response = await state.client
      .from("flashcard_decks")
      .select("id, owner_id, title, description, created_at, updated_at, flashcards(count)")
      .order("updated_at", { ascending: false });

    if (response.error) throw response.error;
    state.decks = response.data || [];
    renderDecks();
  }

  function updateCardNumbers() {
    const rows = Array.from(elements.cardsEditor.querySelectorAll(".card-editor-row"));
    rows.forEach(function (row, index) {
      row.querySelector(".card-number").textContent = String(index + 1).padStart(2, "0");
      row.querySelector(".remove-card-button").disabled = rows.length === 1;
    });
    elements.cardCount.textContent = rows.length + (rows.length === 1 ? " cartão" : " cartões");
  }

  function addCardRow(card) {
    const fragment = elements.cardRowTemplate.content.cloneNode(true);
    const row = fragment.querySelector(".card-editor-row");
    row.querySelector(".english-input").value = card && card.english_word ? card.english_word : "";
    row.querySelector(".translation-input").value = card && card.translation ? card.translation : "";
    elements.cardsEditor.appendChild(fragment);
    updateCardNumbers();
  }

  function readEditorCards() {
    return Array.from(elements.cardsEditor.querySelectorAll(".card-editor-row")).map(function (row) {
      return {
        english_word: row.querySelector(".english-input").value.trim(),
        translation: row.querySelector(".translation-input").value.trim()
      };
    });
  }

  async function loadCards(deckId) {
    const response = await state.client
      .from("flashcards")
      .select("id, deck_id, english_word, translation, position")
      .eq("deck_id", deckId)
      .order("position", { ascending: true });
    if (response.error) throw response.error;
    return response.data || [];
  }

  function openNewDeck(ownerId) {
    state.editingDeckId = null;
    state.editingOwnerId = state.isTeacher ? (ownerId || null) : state.user.id;
    elements.editorTitle.textContent = "Novo conjunto";
    elements.deckTitle.value = "";
    elements.deckDescription.value = "";
    elements.deckOwner.value = state.editingOwnerId || "";
    elements.deckOwner.disabled = false;
    elements.cardsEditor.replaceChildren();
    addCardRow();
    setView("editor");
    if (state.isTeacher && !state.editingOwnerId) elements.deckOwner.focus();
    else elements.deckTitle.focus();
  }

  async function openDeckEditor(deckId) {
    const deck = state.decks.find(function (item) { return item.id === deckId; });
    if (!canManageDeck(deck)) {
      showMessage("Você não tem permissão para editar este conjunto.", "error");
      return;
    }

    try {
      const cards = await loadCards(deckId);
      state.editingDeckId = deckId;
      state.editingOwnerId = deck.owner_id;
      elements.editorTitle.textContent = "Editar conjunto";
      elements.deckTitle.value = deck.title;
      elements.deckDescription.value = deck.description || "";
      elements.deckOwner.value = deck.owner_id;
      elements.deckOwner.disabled = true;
      elements.cardsEditor.replaceChildren();
      (cards.length ? cards : [{}]).forEach(addCardRow);
      setView("editor");
      elements.deckTitle.focus();
    } catch (error) {
      showMessage(errorText(error, "Não foi possível abrir o conjunto."), "error");
    }
  }

  async function saveDeck(event) {
    event.preventDefault();
    clearMessage();

    const title = elements.deckTitle.value.trim();
    const description = elements.deckDescription.value.trim();
    const ownerId = state.isTeacher ? elements.deckOwner.value : state.user.id;
    const cards = readEditorCards();
    const incomplete = cards.some(function (card) { return !card.english_word || !card.translation; });

    if (!title) {
      showMessage("Informe um nome para o conjunto.", "error");
      elements.deckTitle.focus();
      return;
    }
    if (!ownerId) {
      showMessage("Selecione o aluno que será o proprietário do conjunto.", "error");
      elements.deckOwner.focus();
      return;
    }
    if (incomplete) {
      showMessage("Preencha a palavra em inglês e a tradução de todos os cartões.", "error");
      return;
    }
    if (!cards.length || cards.length > 200) {
      showMessage("O conjunto deve ter entre 1 e 200 cartões.", "error");
      return;
    }

    elements.saveDeckButton.disabled = true;
    elements.saveDeckButton.textContent = "SALVANDO...";
    try {
      const response = await state.client.rpc("save_flashcard_deck", {
        p_deck_id: state.editingDeckId,
        p_owner_id: ownerId,
        p_title: title,
        p_description: description || null,
        p_cards: cards
      });
      if (response.error) throw response.error;
      await loadDecks();
      setView("library");
      showMessage("Conjunto salvo com sucesso.", "success");
    } catch (error) {
      showMessage(errorText(error, "Não foi possível salvar o conjunto."), "error");
    } finally {
      elements.saveDeckButton.disabled = false;
      elements.saveDeckButton.textContent = "SALVAR CONJUNTO";
    }
  }

  async function deleteDeck(deckId) {
    const deck = state.decks.find(function (item) { return item.id === deckId; });
    if (!canManageDeck(deck)) return;
    if (!window.confirm("Excluir o conjunto “" + deck.title + "” e todos os seus cartões?")) return;

    try {
      const response = await state.client.from("flashcard_decks").delete().eq("id", deckId);
      if (response.error) throw response.error;
      await loadDecks();
      showMessage("Conjunto excluído.", "success");
    } catch (error) {
      showMessage(errorText(error, "Não foi possível excluir o conjunto."), "error");
    }
  }

  function normalizeAnswer(value) {
    return String(value || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLocaleLowerCase("pt-BR")
      .replace(/[^a-z0-9\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  function renderStudyCard() {
    const card = state.studyCards[state.studyIndex];
    if (!card) return;
    state.answerChecked = false;
    elements.studyWord.textContent = card.english_word;
    elements.translationAnswer.value = "";
    elements.translationAnswer.disabled = false;
    elements.answerFeedback.hidden = true;
    elements.answerFeedback.querySelectorAll("[data-grade]").forEach(function (button) {
      button.disabled = false;
    });
    elements.answerResult.className = "answer-result";
    elements.studyProgress.textContent = "Cartão " + (state.studyIndex + 1) + " de " + state.studyCards.length;
    elements.progressBar.style.width = (((state.studyIndex + 1) / state.studyCards.length) * 100) + "%";
    elements.studyScore.textContent = Array.from(state.studyGrades.values()).filter(Boolean).length + " acertos";
    elements.previousCardButton.disabled = state.studyIndex === 0;
    elements.nextCardButton.textContent = state.studyIndex === state.studyCards.length - 1 ? "FINALIZAR" : "PRÓXIMO ›";
    elements.nextCardButton.disabled = true;
    elements.checkAnswerButton.disabled = false;
    elements.translationAnswer.focus();
  }

  async function startStudy(deckId) {
    const deck = state.decks.find(function (item) { return item.id === deckId; });
    if (!deck) return;
    try {
      const cards = await loadCards(deckId);
      if (!cards.length) {
        showMessage("Este conjunto ainda não tem cartões.", "error");
        return;
      }
      state.studyDeckId = deckId;
      state.studyCards = cards.slice();
      state.studyIndex = 0;
      state.studyGrades = new Map();
      elements.studyTitle.textContent = deck.title;
      elements.studyContent.hidden = false;
      elements.studySummary.hidden = true;
      setView("study");
      renderStudyCard();
    } catch (error) {
      showMessage(errorText(error, "Não foi possível iniciar o estudo."), "error");
    }
  }

  function checkAnswer() {
    const answer = elements.translationAnswer.value.trim();
    if (!answer) {
      showMessage("Digite uma tradução antes de conferir.", "error");
      elements.translationAnswer.focus();
      return;
    }
    clearMessage();
    const card = state.studyCards[state.studyIndex];
    const matches = normalizeAnswer(answer) === normalizeAnswer(card.translation);
    state.answerChecked = true;
    elements.translationAnswer.disabled = true;
    elements.checkAnswerButton.disabled = true;
    elements.expectedTranslation.textContent = card.translation;
    elements.answerResult.textContent = matches ? "A tradução corresponde ao cartão." : "Compare sua resposta com a tradução cadastrada.";
    elements.answerResult.className = "answer-result " + (matches ? "correct" : "review");
    elements.answerFeedback.hidden = false;
    elements.nextCardButton.disabled = false;
  }

  function gradeCurrentCard(isCorrect) {
    const card = state.studyCards[state.studyIndex];
    state.studyGrades.set(card.id, isCorrect);
    elements.studyScore.textContent = Array.from(state.studyGrades.values()).filter(Boolean).length + " acertos";
    const buttons = elements.answerFeedback.querySelectorAll("[data-grade]");
    buttons.forEach(function (button) { button.disabled = true; });
  }

  function showStudySummary() {
    const total = state.studyCards.length;
    const answered = state.studyGrades.size;
    const correct = Array.from(state.studyGrades.values()).filter(Boolean).length;
    elements.studyContent.hidden = true;
    elements.studySummary.hidden = false;
    elements.summaryText.textContent = "Você marcou " + correct + " acertos em " + answered + " cartões avaliados, de um total de " + total + ".";
  }

  function nextStudyCard() {
    if (!state.answerChecked) return;
    if (state.studyIndex >= state.studyCards.length - 1) {
      showStudySummary();
      return;
    }
    state.studyIndex += 1;
    renderStudyCard();
  }

  function previousStudyCard() {
    if (state.studyIndex === 0) return;
    state.studyIndex -= 1;
    renderStudyCard();
  }

  function shuffleStudyCards() {
    for (let index = state.studyCards.length - 1; index > 0; index -= 1) {
      const randomIndex = Math.floor(Math.random() * (index + 1));
      const temporary = state.studyCards[index];
      state.studyCards[index] = state.studyCards[randomIndex];
      state.studyCards[randomIndex] = temporary;
    }
    state.studyIndex = 0;
    state.studyGrades = new Map();
    renderStudyCard();
    showMessage("Cartões embaralhados.", "success");
  }

  function bindEvents() {
    elements.newDeckButton.addEventListener("click", function () { openNewDeck(); });
    elements.studentSearch.addEventListener("input", renderTeacherDirectory);
    elements.cancelEditorButton.addEventListener("click", function () { setView("library"); });
    elements.deckForm.addEventListener("submit", saveDeck);
    elements.addCardButton.addEventListener("click", function () {
      if (elements.cardsEditor.children.length >= 200) {
        showMessage("Cada conjunto pode ter no máximo 200 cartões.", "error");
        return;
      }
      addCardRow();
      elements.cardsEditor.lastElementChild.querySelector(".english-input").focus();
    });
    elements.cardsEditor.addEventListener("click", function (event) {
      const removeButton = event.target.closest(".remove-card-button");
      if (!removeButton || elements.cardsEditor.children.length === 1) return;
      removeButton.closest(".card-editor-row").remove();
      updateCardNumbers();
    });

    document.addEventListener("click", function (event) {
      const actionButton = event.target.closest("[data-action]");
      if (!actionButton) return;
      const deckId = actionButton.dataset.deckId;
      if (actionButton.dataset.action === "study") startStudy(deckId);
      if (actionButton.dataset.action === "edit") openDeckEditor(deckId);
      if (actionButton.dataset.action === "delete") deleteDeck(deckId);
      if (actionButton.dataset.action === "new-for-student") openNewDeck(actionButton.dataset.ownerId);
    });

    elements.checkAnswerButton.addEventListener("click", checkAnswer);
    elements.translationAnswer.addEventListener("keydown", function (event) {
      if (event.key === "Enter") {
        event.preventDefault();
        if (state.answerChecked) nextStudyCard(); else checkAnswer();
      }
    });
    elements.answerFeedback.addEventListener("click", function (event) {
      const gradeButton = event.target.closest("[data-grade]");
      if (gradeButton) gradeCurrentCard(gradeButton.dataset.grade === "right");
    });
    elements.previousCardButton.addEventListener("click", previousStudyCard);
    elements.nextCardButton.addEventListener("click", nextStudyCard);
    elements.shuffleButton.addEventListener("click", shuffleStudyCards);
    elements.leaveStudyButton.addEventListener("click", function () { setView("library"); });
    elements.finishStudyButton.addEventListener("click", function () { setView("library"); });
    elements.restartStudyButton.addEventListener("click", function () { startStudy(state.studyDeckId); });
  }

  async function initialize() {
    cacheElements();
    bindEvents();
    const resourcesReady = await waitForAuthResources();
    if (!resourcesReady) {
      document.body.classList.remove("auth-checking");
      elements.loginStatus.textContent = "Não foi possível carregar a autenticação.";
      showMessage("Atualize a página ou limpe o cache do navegador.", "error");
      return;
    }

    const session = await Auth.getSession();
    if (!session || !session.user) {
      redirectToLogin();
      return;
    }

    state.user = session.user;
    state.client = Auth.getClient();
    const teacherResponse = await state.client.rpc("is_teacher_admin");
    state.isTeacher = !teacherResponse.error && teacherResponse.data === true;
    elements.deckOwnerField.hidden = !state.isTeacher;
    elements.libraryTitle.textContent = state.isTeacher ? "Flashcards por aluno" : "Conjuntos de palavras";
    elements.libraryLead.textContent = state.isTeacher
      ? "Abra os conjuntos de cada aluno para praticar, adicionar palavras, editar traduções ou excluir cartões."
      : "Crie seus próprios cartões e pratique sempre que quiser.";
    elements.newDeckButton.textContent = state.isTeacher ? "+ NOVO CONJUNTO PARA ALUNO" : "+ NOVO CONJUNTO";
    elements.loginStatus.textContent = state.isTeacher
      ? "Professor autenticado. Você pode administrar os conjuntos individuais dos alunos."
      : "Logado como " + state.user.email + ".";
    document.body.classList.remove("auth-checking");

    try {
      await loadStudents();
      await loadDecks();
    } catch (error) {
      if (state.isTeacher) renderEmpty(elements.studentDirectory, "Não foi possível carregar os alunos e seus conjuntos.");
      else renderEmpty(elements.myDecks, "Não foi possível carregar os conjuntos.");
      showMessage(errorText(error, "Não foi possível carregar os flashcards."), "error");
    }
  }

  initialize();
})();
