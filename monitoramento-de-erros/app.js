(function () {
  "use strict";

  const status = document.getElementById("monitorStatus");
  const rows = document.getElementById("errorRows");
  const typeFilter = document.getElementById("typeFilter");
  const stateFilter = document.getElementById("stateFilter");
  const refreshButton = document.getElementById("refreshButton");
  let client = null;

  function setStatus(message) { status.textContent = message; }
  function formatDate(value) {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? "—" : date.toLocaleString("pt-BR", { timeZone: "America/Sao_Paulo" });
  }
  function typeLabel(value) {
    return ({ javascript:"JavaScript", unhandled_promise:"Promise", resource:"Recurso", api:"API/Banco", auth:"Login", payment:"Pagamento", not_found:"404", client_exception:"Exceção" })[value] || value || "—";
  }
  function addTextCell(row, textValue, className) {
    const cell = document.createElement("td");
    if (className) cell.className = className;
    cell.textContent = textValue || "—";
    row.appendChild(cell);
    return cell;
  }
  function render(events) {
    rows.textContent = "";
    if (!events.length) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.colSpan = 6;
      cell.className = "empty";
      cell.textContent = "Nenhuma ocorrência encontrada com estes filtros.";
      row.appendChild(cell);
      rows.appendChild(row);
      return;
    }

    events.forEach(function (event) {
      const row = document.createElement("tr");
      addTextCell(row, formatDate(event.occurred_at));
      const typeCell = document.createElement("td");
      const badge = document.createElement("span");
      badge.className = "badge severity-" + String(event.severity || "error");
      badge.textContent = typeLabel(event.event_type);
      typeCell.appendChild(badge);
      row.appendChild(typeCell);
      addTextCell(row, event.message, "message");
      const requestBits = [event.path || "—"];
      if (event.http_status) requestBits.push(String(event.http_method || "") + " " + String(event.http_status));
      addTextCell(row, requestBits.join(" · "));
      const detailCell = document.createElement("td");
      const details = [];
      if (event.error_code) details.push("Código: " + event.error_code);
      if (event.source) details.push("Origem: " + event.source);
      if (event.stack) details.push(event.stack);
      detailCell.className = "stack";
      detailCell.textContent = details.join("\n") || "—";
      row.appendChild(detailCell);
      const actionCell = document.createElement("td");
      if (event.resolved_at) {
        const resolved = document.createElement("span");
        resolved.className = "resolved";
        resolved.textContent = "Resolvido";
        actionCell.appendChild(resolved);
      } else {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "resolve";
        button.textContent = "RESOLVER";
        button.addEventListener("click", function () { void resolveEvent(event.id, button); });
        actionCell.appendChild(button);
      }
      row.appendChild(actionCell);
      rows.appendChild(row);
    });
  }

  async function loadMetrics() {
    const since24h = new Date(Date.now() - 86400000).toISOString();
    const [unresolved, last24h, payment, auth] = await Promise.all([
      client.from("app_error_events").select("id", { count: "exact", head: true }).is("resolved_at", null),
      client.from("app_error_events").select("id", { count: "exact", head: true }).gte("created_at", since24h),
      client.from("app_error_events").select("id", { count: "exact", head: true }).eq("event_type", "payment").is("resolved_at", null),
      client.from("app_error_events").select("id", { count: "exact", head: true }).eq("event_type", "auth").is("resolved_at", null)
    ]);
    document.getElementById("metricUnresolved").textContent = unresolved.count ?? "—";
    document.getElementById("metric24h").textContent = last24h.count ?? "—";
    document.getElementById("metricPayment").textContent = payment.count ?? "—";
    document.getElementById("metricAuth").textContent = auth.count ?? "—";
  }

  async function loadEvents() {
    refreshButton.disabled = true;
    setStatus("Atualizando ocorrências...");
    let query = client.from("app_error_events")
      .select("id,event_type,severity,message,source,path,stack,error_code,http_status,http_method,occurred_at,created_at,resolved_at")
      .order("created_at", { ascending: false })
      .limit(200);
    if (typeFilter.value) query = query.eq("event_type", typeFilter.value);
    if (stateFilter.value === "unresolved") query = query.is("resolved_at", null);
    if (stateFilter.value === "resolved") query = query.not("resolved_at", "is", null);
    const response = await query;
    refreshButton.disabled = false;
    if (response.error) {
      setStatus("Não foi possível carregar o monitoramento: " + (response.error.message || "erro desconhecido"));
      render([]);
      return;
    }
    render(response.data || []);
    await loadMetrics();
    setStatus("Monitoramento atualizado. Exibindo até 200 ocorrências mais recentes.");
  }

  async function resolveEvent(id, button) {
    button.disabled = true;
    const response = await client.from("app_error_events").update({ resolved_at: new Date().toISOString() }).eq("id", id);
    if (response.error) {
      button.disabled = false;
      setStatus("Não foi possível marcar a ocorrência como resolvida.");
      return;
    }
    await loadEvents();
  }

  async function initialize() {
    for (let attempt = 0; attempt < 20; attempt += 1) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) break;
      await new Promise(function (resolve) { window.setTimeout(resolve, 150); });
    }
    if (!window.Auth || !Auth.isConfigured()) {
      setStatus("Não foi possível carregar a autenticação.");
      return;
    }
    const session = await Auth.getSession();
    if (!session || !session.user) {
      window.location.href = "/login/?next=" + encodeURIComponent("/monitoramento-de-erros/");
      return;
    }
    client = Auth.getClient();
    const admin = await client.rpc("is_teacher_admin");
    if (admin.error || admin.data !== true) {
      setStatus("Acesso negado. Esta página é exclusiva do professor.");
      return;
    }
    document.body.classList.remove("auth-checking");
    await loadEvents();
  }

  typeFilter.addEventListener("change", function () { void loadEvents(); });
  stateFilter.addEventListener("change", function () { void loadEvents(); });
  refreshButton.addEventListener("click", function () { void loadEvents(); });
  void initialize();
})();
