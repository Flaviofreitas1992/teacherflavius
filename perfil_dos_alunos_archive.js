(function () {
  function relabelArchiveButtons(root) {
    const scope = root && root.querySelectorAll ? root : document;
    scope.querySelectorAll(".delete-student-button").forEach(function (button) {
      button.textContent = "ARQUIVAR ALUNO";
      button.title = "Arquivar sem excluir o histórico do aluno";
      button.style.borderColor = "rgba(251,191,36,0.55)";
      button.style.background = "rgba(251,191,36,0.10)";
      button.style.color = "#fde68a";
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
    const button = event.target.closest && event.target.closest(".delete-student-button");
    if (!button) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    archiveStudent(button);
  }, true);

  const observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(function (node) {
        if (node.nodeType === 1) relabelArchiveButtons(node);
      });
    });
  });

  observer.observe(document.documentElement, { childList: true, subtree: true });
  relabelArchiveButtons(document);
})();