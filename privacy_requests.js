(function () {
  "use strict";

  var statusElement;
  var requestButton;
  var cancelButton;
  var activeRequest = null;

  function formatDate(value) {
    if (!value) return "";
    var date = new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    return date.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
  }

  function setStatus(message, type) {
    if (!statusElement) return;
    statusElement.className = "privacy-request-status" + (type ? " " + type : "");
    statusElement.textContent = message || "";
  }

  function renderRequest(request) {
    activeRequest = request && ["open", "in_review"].includes(request.status) ? request : null;

    if (!request) {
      setStatus("Nenhum pedido de encerramento está ativo.");
      requestButton.hidden = false;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "open") {
      setStatus("Pedido registrado em " + formatDate(request.requested_at) + ". Ele ainda pode ser cancelado enquanto não entrar em análise.", "warning");
      requestButton.hidden = true;
      cancelButton.hidden = false;
      return;
    }

    if (request.status === "in_review") {
      setStatus("Seu pedido está em análise. A conta será encerrada após a verificação dos dados que podem ser eliminados e dos registros que precisam ser conservados.", "warning");
      requestButton.hidden = true;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "completed") {
      setStatus("O pedido foi concluído em " + formatDate(request.completed_at) + ".", "success");
      requestButton.hidden = true;
      cancelButton.hidden = true;
      return;
    }

    if (request.status === "cancelled") {
      setStatus("O último pedido foi cancelado. Você pode fazer uma nova solicitação se necessário.");
      requestButton.hidden = false;
      cancelButton.hidden = true;
      return;
    }

    setStatus("O último pedido foi encerrado sem exclusão. Entre em contato se precisar de esclarecimentos.");
    requestButton.hidden = false;
    cancelButton.hidden = true;
  }

  async function loadLatestRequest() {
    var client = Auth.getClient();
    var response = await client
      .from("data_subject_requests")
      .select("id,status,requested_at,reviewed_at,completed_at,resolution_note,retention_summary")
      .eq("request_type", "account_deletion")
      .order("requested_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (response.error) throw response.error;
    renderRequest(response.data || null);
  }

  async function createRequest() {
    var confirmed = window.confirm(
      "Deseja solicitar o encerramento da sua conta?\n\nO pedido não apaga tudo imediatamente. O professor fará a análise e eliminará ou anonimizará os dados que não precisem ser mantidos. Registros financeiros necessários para obrigações legais ou exercício de direitos poderão ser conservados de forma restrita."
    );
    if (!confirmed) return;

    requestButton.disabled = true;
    requestButton.textContent = "REGISTRANDO PEDIDO...";
    setStatus("Registrando sua solicitação...");

    try {
      var response = await Auth.getClient().rpc("request_account_deletion");
      if (response.error) throw response.error;
      await loadLatestRequest();
    } catch (error) {
      setStatus(error.message || "Não foi possível registrar o pedido.", "error");
    } finally {
      requestButton.disabled = false;
      requestButton.textContent = "SOLICITAR ENCERRAMENTO DA CONTA";
    }
  }

  async function cancelRequest() {
    if (!activeRequest || activeRequest.status !== "open") return;
    if (!window.confirm("Cancelar este pedido de encerramento da conta?")) return;

    cancelButton.disabled = true;
    try {
      var response = await Auth.getClient().rpc("cancel_my_account_deletion_request", { p_request_id: activeRequest.id });
      if (response.error) throw response.error;
      await loadLatestRequest();
    } catch (error) {
      setStatus(error.message || "Não foi possível cancelar o pedido.", "error");
    } finally {
      cancelButton.disabled = false;
    }
  }

  async function init() {
    statusElement = document.getElementById("privacyRequestStatus");
    requestButton = document.getElementById("requestAccountDeletionButton");
    cancelButton = document.getElementById("cancelAccountDeletionButton");
    if (!statusElement || !requestButton || !cancelButton || !window.Auth) return;

    requestButton.addEventListener("click", createRequest);
    cancelButton.addEventListener("click", cancelRequest);

    try {
      var user = await Auth.requireAuth();
      if (!user) return;
      await loadLatestRequest();
    } catch (error) {
      setStatus(error.message || "Não foi possível consultar suas solicitações de privacidade.", "error");
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init, { once: true });
  else init();
})();