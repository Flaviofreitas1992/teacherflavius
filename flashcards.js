(function () {
  "use strict";

  const GRADE_META = {
    again: { label: "Não lembrei" },
    hard: { label: "Difícil" },
    good: { label: "Lembrei" },
    easy: { label: "Fácil" }
  };

  const state = {
    client: null,
    user: null,
    isTeacher: false,
    decks: [],
    students: [],
    practiceByStudent: new Map(),
    practiceRecordedToday: false,
    cardDeckById: new Map(),
    srsByCard: new Map(),
    dueCountByDeck: new Map(),
    srsAvailable: true,
    editingDeckId: null,
    editingOwnerId: null,
    studyDeckId: null,
    studyMode: "due",
    studyCards: [],
    studyIndex: 0,
    studyGrades: new Map(),
    answerChecked: false,
    reviewSaving: false
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
      "answerResult", "expectedTranslation", "reviewSchedule", "previousCardButton", "nextCardButton",
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
    if (/save_flashcard_deck|record_flashcard_review|flashcard_decks|flashcards|flashcard_srs|flashcard_review_history/i.test(message)
        && /not find|schema cache|does not exist/i.test(message)) {
      return "O banco de flashcards precisa da atualização de repetição espaçada. Aplique a migração SRS do projeto no Supabase.";
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

  function dueCountForDeck(deck) {
    if (!deck) return 0;
    if (!state.srsAvailable) return deckCardCount(deck);
    return Number(state.dueCountByDeck.get(deck.id) || 0);
  }

  function canManageDeck(deck) {
    return !!deck && (deck.owner_id === state.user.id || state.isTeacher);
  }

  function studentDisplayName(student) {
    return student && student.name ? student.name : student && student.email ? student.email : "Aluno";
  }

  function saoPauloToday() {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Sao_Paulo",
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    }).formatToParts(new Date());
    const values = {};
    parts.forEach(function (part) { values[part.type] = part.value; });
    return values.year + "-" + values.month + "-" + values.day;
  }

  function dateOffset(isoDate, offset) {
    const parts = isoDate.split("-").map(Number);
    const date = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2] + offset, 12));
    return date.toISOString().slice(0, 10);
  }

  function lastPracticeDates() {
    const today = saoPauloToday();
    return Array.from({ length: 20 }, function (_, index) {
      return dateOffset(today, index - 19);
    });
  }

  function formatPracticeDate(isoDate, options) {
    return new Intl.DateTimeFormat("pt-BR", Object.assign({ timeZone: "UTC" }, options))
      .format(new Date(isoDate + "T12:00:00Z"));
  }

  function formatDueDate(isoDate) {
    const today = saoPauloToday();
    if (!isoDate || isoDate <= today) return "hoje";
    if (isoDate === dateOffset(today, 1)) return "amanhã";
    return formatPracticeDate(isoDate, { day: "2-digit", month: "short", year: "numeric" });
  }

  function isCardDue(card) {
    const srs = state.srsByCard.get(card.id);
    return !srs || !srs.due_date || srs.due_date <= saoPauloToday();
  }

  function recalculateDueCounts() {
    state.dueCountByDeck = new Map();
    state.cardDeckById.forEach(function (deckId, cardId) {
      const srs = state.srsByCard.get(cardId);
      if (!srs || !srs.due_date || srs.due_date <= saoPauloToday()) {
        state.dueCountByDeck.set(deckId, Number(state.dueCountByDeck.get(deckId) || 0) + 1);
      }
    });
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
    const due = dueCountForDeck(deck);
    const meta = document.createElement("p");
    meta.className = "deck-meta";
    const cardText = count + (count === 1 ? " cartão" : " cartões");
    const dueText = due === 0
      ? "em dia hoje"
      : due + " para revisar hoje";
    meta.textContent = cardText + " · " + dueText;
    article.appendChild(meta);

    const actions = document.createElement("div");
    actions.className = "deck-actions";

    if (state.isTeacher) {
      const studyButton = createActionButton("ESTUDAR", "button-primary", "study-all", deck.id);
      studyButton.disabled = count === 0;
      actions.appendChild(studyButton);
    } else {
      const reviewLabel = due > 0 ? "REVISAR (" + due + ")" : "EM DIA ✓";
      const reviewButton = createActionButton(reviewLabel, "button-primary", "study-due", deck.id);
      reviewButton.disabled = count === 0 || due === 0;
      actions.appendChild(reviewButton);

      const allButton = createActionButton("ESTUDAR TODOS", "button-secondary", "study-all", deck.id);
      allButton.disabled = count === 0;
      actions.appendChild(allButton);
    }

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

  function createPracticeHistory(student) {
    const dates = lastPracticeDates();
    const practicedDates = state.practiceByStudent.get(student.user_id) || new Set();
    const wrapper = document.createElement("div");
    wrapper.className = "practice-history";

    const heading = document.createElement("div");
    heading.className = "practice-history-heading";
    const title = document.createElement("span");
    title.textContent = "Prática nos últimos 20 dias";
    const count = document.createElement("strong");
    const practicedCount = dates.filter(function (date) { return practicedDates.has(date); }).length;
    count.textContent = practicedCount + (practicedCount === 1 ? " dia praticado" : " dias praticados");
    heading.append(title, count);
    wrapper.appendChild(heading);

    const strip = document.createElement("div");
    strip.className = "practice-days";
    strip.setAttribute("role", "list");
    strip.setAttribute("aria-label", "Dias de prática de " + studentDisplayName(student) + " nos últimos 20 dias");

    dates.forEach(function (isoDate) {
      const practiced = practicedDates.has(isoDate);
      const day = document.createElement("span");
      day.className = "practice-day" + (practiced ? " practiced" : "");
      day.setAttribute("role", "listitem");
      const fullDate = formatPracticeDate(isoDate, { day: "2-digit", month: "long", year: "numeric" });
      day.setAttribute("title", fullDate + (practiced ? " — praticou" : " — sem prática registrada"));
      day.setAttribute("aria-label", fullDate + (practiced ? ": praticou" : ": sem prática registrada"));

      const weekday = document.createElement("small");
      weekday.textContent = formatPracticeDate(isoDate, { weekday: "short" }).replace(".", "").slice(0, 3);
      const number = document.createElement("b");
      number.textContent = isoDate.slice(8, 10);
      day.append(weekday, number);
      strip.appendChild(day);
    });

    wrapper.appendChild(strip);
    return wrapper;
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
    section.appendChild(createPracticeHistory(student));

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

  async function loadPracticeDays() {
    if (!state.isTeacher) return;
    const dates = lastPracticeDates();
    const response = await state.client
      .from("flashcard_practice_days")
      .select("user_id, practice_date")
      .gte("practice_date", dates[0])
      .lte("practice_date", dates[dates.length - 1])
      .order("practice_date", { ascending: true });
    if (response.error) throw response.error;

    state.practiceByStudent = new Map();
    (response.data || []).forEach(function (entry) {
      if (!state.practiceByStudent.has(entry.user_id)) {
        state.practiceByStudent.set(entry.user_id, new Set());
      }
      state.practiceByStudent.get(entry.user_id).add(entry.practice_date);
    });
  }

  async function recordPracticeDay() {
    if (state.isTeacher || state.practiceRecordedToday) return;
    state.practiceRecordedToday = true;
    try {
      const response = await state.client.rpc("record_flashcard_practice_day");
      if (response.error) {
        state.practiceRecordedToday = false;
        console.warn("Não foi possível registrar o dia de prática dos flashcards.", response.error);
      }
    } catch (error) {
      state.practiceRecordedToday = false;
      console.warn("Não foi possível registrar o dia de prática dos flashcards.", error);
    }
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

  async function fetchAllRows(table, columns, orderColumn) {
    const rows = [];
    const pageSize = 1000;
    let from = 0;

    while (true) {
      const response = await state.client
        .from(table)
        .select(columns)
        .order(orderColumn, { ascending: true })
        .range(from, from + pageSize - 1);
      if (response.error) throw response.error;
      const page = response.data || [];
      rows.push.apply(rows, page);
      if (page.length < pageSize) break;
      from += pageSize;
    }
    return rows;
  }

  async function loadSrsOverview() {
    const cards = await fetchAllRows("flashcards", "id, deck_id", "id");
    const srsRows = await fetchAllRows(
      "flashcard_srs",
      "user_id, card_id, ease_factor, interval_days, repetitions, lapses, due_date, last_grade, last_reviewed_at",
      "card_id"
    );

    state.cardDeckById = new Map();
    cards.forEach(function (card) { state.cardDeckById.set(card.id, card.deck_id); });

    state.srsByCard = new Map();
    srsRows.forEach(function (srs) { state.srsByCard.set(srs.card_id, srs); });
    state.srsAvailable = true;
    recalculateDueCounts();
  }

  async function loadDecks() {
    elements.myDecks.innerHTML = '<div class="empty-state">Carregando seus conjuntos...</div>';
    const response = await state.client
      .from("flashcard_decks")
      .select("id, owner_id, title, description, created_at, updated_at, flashcards(count)")
      .order("updated_at", { ascending: false });

    if (response.error) throw response.error;
    state.decks = response.data || [];

    try {
      await loadSrsOverview();
    } catch (error) {
      state.srsAvailable = false;
      state.cardDeckById = new Map();
      state.srsByCard = new Map();
      state.dueCountByDeck = new Map();
      state.decks.forEach(function (deck) {
        state.dueCountByDeck.set(deck.id, deckCardCount(deck));
      });
      console.warn("Repetição espaçada indisponível; usando modo compatível.", error);
    }

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
    row.dataset.cardId = card && card.id ? card.id : "";
    row.querySelector(".english-input").value = card && card.english_word ? card.english_word : "";
    row.querySelector(".translation-input").value = card && card.translation ? card.translation : "";
    elements.cardsEditor.appendChild(fragment);
    updateCardNumbers();
  }

  function readEditorCards() {
    return Array.from(elements.cardsEditor.querySelectorAll(".card-editor-row")).map(function (row) {
      const card = {
        english_word: row.querySelector(".english-input").value.trim(),
        translation: row.querySelector(".translation-input").value.trim()
      };
      if (row.dataset.cardId) card.id = row.dataset.cardId;
      return card;
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
      showMessage("Conjunto salvo com sucesso. O progresso de revisão dos cartões mantidos foi preservado.", "success");
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

  function gradeButtons() {
    return Array.from(elements.answerFeedback.querySelectorAll("[data-grade]"));
  }

  function setGradeButtonsDisabled(disabled) {
    gradeButtons().forEach(function (button) { button.disabled = disabled; });
  }

  function renderStudyScore() {
    const reviewed = state.studyGrades.size;
    elements.studyScore.textContent = reviewed + (reviewed === 1 ? " revisado" : " revisados");
  }

  function renderSavedReview(card, grade) {
    const srs = state.srsByCard.get(card.id);
    const meta = GRADE_META[grade] || { label: "Avaliado" };
    elements.reviewSchedule.textContent = state.isTeacher
      ? meta.label + ". Prévia do professor: a agenda do aluno não foi alterada."
      : meta.label + ". Próxima revisão: " + formatDueDate(srs && srs.due_date) + ".";
  }

  function renderStudyCard() {
    const card = state.studyCards[state.studyIndex];
    if (!card) return;

    const existingGrade = state.studyGrades.get(card.id);
    state.answerChecked = !!existingGrade;
    state.reviewSaving = false;
    elements.studyWord.textContent = card.english_word;
    elements.translationAnswer.value = "";
    elements.answerResult.className = "answer-result";
    elements.studyProgress.textContent = "Cartão " + (state.studyIndex + 1) + " de " + state.studyCards.length;
    elements.progressBar.style.width = (((state.studyIndex + 1) / state.studyCards.length) * 100) + "%";
    renderStudyScore();
    elements.previousCardButton.disabled = state.studyIndex === 0;
    elements.nextCardButton.textContent = state.studyIndex === state.studyCards.length - 1 ? "FINALIZAR" : "PRÓXIMO ›";
    elements.shuffleButton.disabled = state.studyGrades.size > 0;

    if (existingGrade) {
      elements.translationAnswer.disabled = true;
      elements.checkAnswerButton.disabled = true;
      elements.answerFeedback.hidden = false;
      elements.answerResult.textContent = "Este cartão já foi avaliado nesta sessão.";
      elements.expectedTranslation.textContent = card.translation;
      setGradeButtonsDisabled(true);
      renderSavedReview(card, existingGrade);
      elements.nextCardButton.disabled = false;
      return;
    }

    elements.translationAnswer.disabled = false;
    elements.checkAnswerButton.disabled = false;
    elements.answerFeedback.hidden = true;
    elements.reviewSchedule.textContent = "";
    setGradeButtonsDisabled(false);
    elements.nextCardButton.disabled = true;
    elements.translationAnswer.focus();
  }

  async function startStudy(deckId, mode) {
    const deck = state.decks.find(function (item) { return item.id === deckId; });
    if (!deck) return;

    try {
      let cards = await loadCards(deckId);
      if (!cards.length) {
        showMessage("Este conjunto ainda não tem cartões.", "error");
        return;
      }

      const studyMode = mode === "all" || state.isTeacher ? "all" : "due";
      if (studyMode === "due") {
        cards = cards.filter(isCardDue).sort(function (a, b) {
          const aDue = (state.srsByCard.get(a.id) || {}).due_date || saoPauloToday();
          const bDue = (state.srsByCard.get(b.id) || {}).due_date || saoPauloToday();
          return aDue.localeCompare(bDue) || Number(a.position || 0) - Number(b.position || 0);
        });
      }

      if (!cards.length) {
        renderDecks();
        showMessage("Você está em dia neste conjunto. Nenhum cartão precisa ser revisado hoje.", "success");
        return;
      }

      state.studyDeckId = deckId;
      state.studyMode = studyMode;
      state.studyCards = cards.slice();
      state.studyIndex = 0;
      state.studyGrades = new Map();
      state.answerChecked = false;
      state.reviewSaving = false;
      elements.studyTitle.textContent = studyMode === "due" ? deck.title + " — revisão de hoje" : deck.title;
      elements.restartStudyButton.textContent = studyMode === "due" ? "REVISAR DE NOVO" : "ESTUDAR NOVAMENTE";
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
    elements.answerResult.textContent = matches
      ? "A tradução corresponde ao cartão."
      : "Compare sua resposta com a tradução cadastrada.";
    elements.answerResult.className = "answer-result " + (matches ? "correct" : "review");
    elements.answerFeedback.hidden = false;
    elements.nextCardButton.disabled = true;
    elements.shuffleButton.disabled = true;
    setGradeButtonsDisabled(false);
    elements.reviewSchedule.textContent = state.isTeacher
      ? "Escolha uma avaliação para continuar. A prévia do professor não altera a agenda do aluno."
      : "Como foi lembrar? Escolha uma opção para calcular a próxima revisão.";
    recordPracticeDay();
  }

  async function gradeCurrentCard(grade) {
    const card = state.studyCards[state.studyIndex];
    if (!card || !state.answerChecked || state.reviewSaving || !GRADE_META[grade]) return;
    if (state.studyGrades.has(card.id)) return;

    state.reviewSaving = true;
    setGradeButtonsDisabled(true);
    elements.nextCardButton.disabled = true;

    try {
      if (!state.isTeacher) {
        if (!state.srsAvailable) {
          throw new Error("A repetição espaçada ainda não está disponível no banco de dados.");
        }

        const response = await state.client.rpc("record_flashcard_review", {
          p_card_id: card.id,
          p_grade: grade
        });
        if (response.error) throw response.error;

        const saved = response.data || {};
        state.srsByCard.set(card.id, {
          user_id: state.user.id,
          card_id: card.id,
          ease_factor: Number(saved.ease_factor || 2.5),
          interval_days: Number(saved.interval_days || 0),
          repetitions: Number(saved.repetitions || 0),
          lapses: Number(saved.lapses || 0),
          due_date: saved.due_date || saoPauloToday(),
          last_grade: saved.grade || grade,
          last_reviewed_at: saved.last_reviewed_at || new Date().toISOString()
        });
        recalculateDueCounts();
      }

      state.studyGrades.set(card.id, grade);
      renderStudyScore();
      renderSavedReview(card, grade);
      elements.nextCardButton.disabled = false;
      elements.shuffleButton.disabled = true;
    } catch (error) {
      showMessage(errorText(error, "Não foi possível salvar esta revisão."), "error");
      setGradeButtonsDisabled(false);
    } finally {
      state.reviewSaving = false;
    }
  }

  function showStudySummary() {
    const counts = { again: 0, hard: 0, good: 0, easy: 0 };
    state.studyGrades.forEach(function (grade) {
      if (Object.prototype.hasOwnProperty.call(counts, grade)) counts[grade] += 1;
    });

    const reviewed = state.studyGrades.size;
    const total = state.studyCards.length;
    const base = "Você revisou " + reviewed + " de " + total + " cartões. "
      + "Não lembrei: " + counts.again + " · Difícil: " + counts.hard
      + " · Lembrei: " + counts.good + " · Fácil: " + counts.easy + ".";

    let suffix = "";
    if (state.isTeacher) {
      suffix = " Esta foi uma prévia: nenhuma agenda de revisão do aluno foi alterada.";
    } else {
      const remaining = Number(state.dueCountByDeck.get(state.studyDeckId) || 0);
      suffix = remaining > 0
        ? " Ainda há " + remaining + (remaining === 1 ? " cartão devido hoje." : " cartões devidos hoje.")
        : " Você está em dia neste conjunto.";
    }

    elements.studyContent.hidden = true;
    elements.studySummary.hidden = false;
    elements.summaryText.textContent = base + suffix;
  }

  function nextStudyCard() {
    const card = state.studyCards[state.studyIndex];
    if (!card || !state.answerChecked || !state.studyGrades.has(card.id) || state.reviewSaving) return;
    if (state.studyIndex >= state.studyCards.length - 1) {
      showStudySummary();
      return;
    }
    state.studyIndex += 1;
    renderStudyCard();
  }

  function previousStudyCard() {
    if (state.studyIndex === 0 || state.reviewSaving) return;
    state.studyIndex -= 1;
    renderStudyCard();
  }

  function shuffleStudyCards() {
    if (state.studyGrades.size > 0 || state.answerChecked) {
      showMessage("Embaralhe antes de iniciar as avaliações para não duplicar revisões já registradas.", "error");
      return;
    }
    for (let index = state.studyCards.length - 1; index > 0; index -= 1) {
      const randomIndex = Math.floor(Math.random() * (index + 1));
      const temporary = state.studyCards[index];
      state.studyCards[index] = state.studyCards[randomIndex];
      state.studyCards[randomIndex] = temporary;
    }
    state.studyIndex = 0;
    renderStudyCard();
    showMessage("Cartões embaralhados.", "success");
  }

  function finishStudy() {
    setView("library");
    renderDecks();
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
      if (actionButton.dataset.action === "study-due") startStudy(deckId, "due");
      if (actionButton.dataset.action === "study-all" || actionButton.dataset.action === "study") startStudy(deckId, "all");
      if (actionButton.dataset.action === "edit") openDeckEditor(deckId);
      if (actionButton.dataset.action === "delete") deleteDeck(deckId);
      if (actionButton.dataset.action === "new-for-student") openNewDeck(actionButton.dataset.ownerId);
    });

    elements.checkAnswerButton.addEventListener("click", checkAnswer);
    elements.translationAnswer.addEventListener("keydown", function (event) {
      if (event.key === "Enter") {
        event.preventDefault();
        const card = state.studyCards[state.studyIndex];
        if (state.answerChecked && card && state.studyGrades.has(card.id)) nextStudyCard();
        else if (!state.answerChecked) checkAnswer();
      }
    });
    elements.answerFeedback.addEventListener("click", function (event) {
      const gradeButton = event.target.closest("[data-grade]");
      if (gradeButton) gradeCurrentCard(gradeButton.dataset.grade);
    });
    elements.previousCardButton.addEventListener("click", previousStudyCard);
    elements.nextCardButton.addEventListener("click", nextStudyCard);
    elements.shuffleButton.addEventListener("click", shuffleStudyCards);
    elements.leaveStudyButton.addEventListener("click", finishStudy);
    elements.finishStudyButton.addEventListener("click", finishStudy);
    elements.restartStudyButton.addEventListener("click", function () { startStudy(state.studyDeckId, state.studyMode); });
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
      ? "Abra os conjuntos de cada aluno para estudar ou editar. A prévia do professor não altera a agenda de repetição espaçada do aluno."
      : "Revise primeiro o que está devido hoje. O sistema agenda cada cartão novamente conforme sua autoavaliação.";
    elements.newDeckButton.textContent = state.isTeacher ? "+ NOVO CONJUNTO PARA ALUNO" : "+ NOVO CONJUNTO";
    elements.loginStatus.textContent = state.isTeacher
      ? "Professor autenticado. Você pode administrar os conjuntos individuais dos alunos."
      : "Logado como " + state.user.email + ".";
    document.body.classList.remove("auth-checking");

    try {
      await loadStudents();
      await loadPracticeDays();
      await loadDecks();
    } catch (error) {
      if (state.isTeacher) renderEmpty(elements.studentDirectory, "Não foi possível carregar os alunos e seus conjuntos.");
      else renderEmpty(elements.myDecks, "Não foi possível carregar os conjuntos.");
      showMessage(errorText(error, "Não foi possível carregar os flashcards."), "error");
    }
  }

  initialize();
})();