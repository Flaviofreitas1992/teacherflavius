(function () {
  function collectDeleteButtons(root) {
    const buttons = [];
    const scope = root && root.querySelectorAll ? root : document;

    if (scope.matches && scope.matches(".delete-student-button")) {
      buttons.push(scope);
    }

    scope.querySelectorAll(".delete-student-button").forEach(function (button) {
      buttons.push(button);
    });

    return buttons;
  }

  function ensureArchiveButtons(root) {
    collectDeleteButtons(root).forEach(function (deleteButton) {
      if (deleteButton.dataset.archiveButtonAdded === "1") return;

      deleteButton.dataset.archiveButtonAdded = "1";
      deleteButton.textContent = "EXCLUIR ALUNO";
      deleteButton.title = "Excluir definitivamente a conta e os dados vinculados ao aluno";
      deleteButton.style.borderColor = "rgba(248,113,113,0.55)";
      deleteButton.style.background = "rgba(248,113,113,0.10)";
      deleteButton.style.color = "#fca5a5";

      const archiveButton = document.createElement("button");
      archiveButton.className = "delete-button archive-student-button";
      archiveButton.type = "button";
      archiveButton.dataset.userId = deleteButton.dataset.userId || "";
      archiveButton.dataset.studentName = deleteButton.dataset.studentName || "";
      archiveButton.textContent = "ARQUIVAR ALUNO";
      archiveButton.title = "Arquivar sem excluir o histórico do aluno";
      archiveButton.style.borderColor = "rgba(251,191,36,0.55)";
      archiveButton.style.background = "rgba(251,191,36,0.10)";
      archiveButton.style.color = "#fde68a";

      deleteButton.parentNode.insertBefore(archiveButton, deleteButton);
    });
  }

  async function archiveStudent(button) {
    const userId = button.dataset.userId;
    const studentName = button.dataset.studentName || "este aluno";
    if (!userId) return;

    const confirmed = window.confirm(
      "Arquivar o aluno " + studentName + "?\n\n" +
      "O aluno deixará de aparecer nas listas de alunos ativos da Área do Professor, " +
      "mas matrícula, atividades, frequência, flashcards e demais históricos permanecerão salvos."
    );
    if (!confirmed) return;

    button.disabled = true;
    button.textContent = "ARQUIVANDO...";

    try {
      const client = Auth.getClient();
      const response = await client.rpc("archive_teacher_student", { target_user_id: userId });
      if (response.error) throw response.error;
      window.location.reload();
    } catch (error) {
      alert("Não foi possível arquivar o aluno: " + (error.message || "erro desconhecido") + ".");
      button.disabled = false;
      button.textContent = "ARQUIVAR ALUNO";
    }
  }

  document.addEventListener("click", function (event) {
    const button = event.target.closest && event.target.closest(".archive-student-button");
    if (!button) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    archiveStudent(button);
  }, true);

  const observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(function (node) {
        if (node.nodeType === 1) ensureArchiveButtons(node);
      });
    });
  });

  observer.observe(document.documentElement, { childList: true, subtree: true });
  ensureArchiveButtons(document);
})();
