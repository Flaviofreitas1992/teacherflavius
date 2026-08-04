(function () {
  "use strict";

  const state = {
    client: null,
    user: null,
    isTeacher: false,
    decks: [],
    editingDeckId: null,
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
      "sharedSection", "sharedDecks", "myDecks", "newDeckButton", "cancelEditorButton",
      "deckForm", "deckTitle", "deckDescription", "sharedField", "deckShared",
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

    if (deck.owner_id === state.user.id) {
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

    if (deck.is_shared) {
      const pill = document.createElement("span");
      pill.className = "shared-pill";
      pill.textContent = deck.owner_id === state.user.id ? "Compartilhado com os alunos" : "Criado pelo professor";
      article.appendChild(pill);
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
    if (deck.owner_id === state.user.id) {
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

  function renderDecks() {
    const sharedDecks = state.decks.filter(function (deck) {
      return deck.is_shared && deck.owner_id !== state.user.id;
    });
    const ownDecks = state.decks.filter(function (deck) { return deck.owner_id === state.user.id; });

    elements.sharedSection.hidden = sharedDecks.length === 0;
    elements.sharedDecks.replaceChildren.apply(elements.sharedDecks, sharedDecks.map(createDeckCard));

    if (ownDecks.length) {
      elements.myDecks.replaceChildren.apply(elements.myDecks, ownDecks.map(createDeckCard));
    } else {
      renderEmpty(elements.myDecks, "Você ainda não criou nenhum conjunto. Clique em “Novo conjunto” para começar.");
    }
  }

  async function loadDecks() {
    elements.myDecks.innerHTML = '<div class="empty-state">Carregando seus conjuntos...</div>';
    const response = await state.client
      .from("flashcard_decks")
      .select("id, owner_id, title, description, is_shared, created_at, updated_at, flashcards(count)")
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

  function openNewDeck() {
    state.editingDeckId = null;
    elements.editorTitle.textContent = "Novo conjunto";
    elements.deckTitle.value = "";
    elements.deckDescription.value = "";
    elements.deckShared.checked = false;
    elements.cardsEditor.replaceChildren();
    addCardRow();
    setView("editor");
    elements.deckTitle.focus();
  }

  async function openDeckEditor(deckId) {
    const deck = state.decks.find(function (item) { return item.id === deckId; });
    if (!deck || deck.owner_id !== state.user.id) {
      showMessage("Você não tem permissão para editar este conjunto.", "error");
      return;
    }

    try {
      const cards = await loadCards(deckId);
      state.editingDeckId = deckId;
      elements.editorTitle.textContent = "Editar conjunto";
      elements.deckTitle.value = deck.title;
      elements.deckDescription.value = deck.description || "";
      elements.deckShared.checked = deck.is_shared === true;
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
    const cards = readEditorCards();
    const incomplete = cards.some(function (card) { return !card.english_word || !card.translation; });

    if (!title) {
      showMessage("Informe um nome para o conjunto.", "error");
      elements.deckTitle.focus();
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
        p_title: title,
        p_description: description || null,
        p_is_shared: state.isTeacher && elements.deckShared.checked,
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
    if (!deck || deck.owner_id !== state.user.id) return;
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
    elements.newDeckButton.addEventListener("click", openNewDeck);
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
    elements.sharedField.hidden = !state.isTeacher;
    elements.loginStatus.textContent = state.isTeacher
      ? "Professor autenticado. Você pode criar conjuntos para todos os alunos."
      : "Logado como " + state.user.email + ".";
    document.body.classList.remove("auth-checking");

    try {
      await loadDecks();
    } catch (error) {
      renderEmpty(elements.myDecks, "Não foi possível carregar os conjuntos.");
      showMessage(errorText(error, "Não foi possível carregar os flashcards."), "error");
    }
  }

  initialize();
})();
