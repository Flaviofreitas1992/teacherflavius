(function () {
  let currentSession = null;

  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  async function waitForResources() {
    for (let attempt = 0; attempt < 15; attempt++) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return !!(window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured());
  }

  function setStatus(text, isError) {
    const status = document.getElementById("accessStatus");
    status.textContent = text;
    status.style.color = isError ? "#fca5a5" : "#94a3b8";
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  function formatDateTime(value) {
    if (!value) return "Data não informada";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return String(value);
    return new Intl.DateTimeFormat("pt-BR", {
      dateStyle: "short",
      timeStyle: "medium"
    }).format(date);
  }

  function locationLabel(status) {
    const labels = {
      granted: "Compartilhada",
      denied: "Negada no navegador",
      unavailable: "Indisponível",
      error: "Erro ao obter",
      not_shared: "Não compartilhada"
    };
    return labels[status] || "Não compartilhada";
  }

  function renderStudents(students) {
    const select = document.getElementById("studentFilter");
    const selectedValue = select.value;
    const unique = new Map();

    (students || []).forEach(function (student) {
      const userId = student.user_id || student.id;
      if (!userId || unique.has(userId)) return;
      unique.set(userId, {
        id: userId,
        name: student.name || student.email || "Aluno",
        email: student.email || ""
      });
    });

    const sorted = Array.from(unique.values()).sort(function (a, b) {
      return a.name.localeCompare(b.name, "pt-BR", { sensitivity: "base" });
    });

    select.innerHTML = '<option value="">Todos os alunos</option>' + sorted.map(function (student) {
      const label = student.email
        ? student.name + " · " + student.email
        : student.name;
      return '<option value="' + escapeHtml(student.id) + '">' + escapeHtml(label) + "</option>";
    }).join("");

    if (Array.from(select.options).some(function (option) { return option.value === selectedValue; })) {
      select.value = selectedValue;
    }
  }

  function renderSummary(accesses) {
    const studentIds = new Set();
    const pages = new Set();
    let sharedLocations = 0;

    accesses.forEach(function (access) {
      if (access.user_id) studentIds.add(access.user_id);
      if (access.page_path) pages.add(access.page_path);
      if (access.location_status === "granted" && access.latitude != null && access.longitude != null) {
        sharedLocations++;
      }
    });

    document.getElementById("totalAccesses").textContent = String(accesses.length);
    document.getElementById("activeStudents").textContent = String(studentIds.size);
    document.getElementById("uniquePages").textContent = String(pages.size);
    document.getElementById("sharedLocations").textContent = String(sharedLocations);
  }

  function renderAccesses(accesses) {
    const message = document.getElementById("accessMessage");
    const tableWrap = document.getElementById("accessTableWrap");
    const tbody = document.getElementById("accessTableBody");

    renderSummary(accesses);

    if (!accesses.length) {
      tbody.innerHTML = "";
      tableWrap.hidden = true;
      message.hidden = false;
      message.className = "empty";
      message.textContent = "Nenhum acesso foi encontrado para os filtros selecionados.";
      return;
    }

    tbody.innerHTML = accesses.map(function (access) {
      const pageTitle = access.page_title || "Página sem título";
      const pagePath = access.page_path || "/";
      const hasLocation = access.location_status === "granted"
        && access.latitude != null
        && access.longitude != null;
      let locationHtml = '<span class="location-status">' +
        escapeHtml(locationLabel(access.location_status)) +
        "</span>";

      if (hasLocation) {
        const latitude = Number(access.latitude);
        const longitude = Number(access.longitude);
        const mapUrl = "https://www.openstreetmap.org/?mlat=" +
          encodeURIComponent(latitude) +
          "&mlon=" +
          encodeURIComponent(longitude) +
          "#map=12/" +
          encodeURIComponent(latitude) +
          "/" +
          encodeURIComponent(longitude);
        locationHtml = [
          '<span class="location-status shared">Compartilhada</span><br>',
          escapeHtml(latitude.toFixed(2) + ", " + longitude.toFixed(2)),
          '<br><a class="map-link" href="' + mapUrl + '" target="_blank" rel="noopener noreferrer">Abrir mapa</a>'
        ].join("");
      }

      return [
        "<tr>",
        '<td><span class="student-name">' + escapeHtml(access.student_name || "Aluno") + "</span>",
        '<div class="muted">' + escapeHtml(access.student_email || "") + "</div></td>",
        "<td>" + escapeHtml(formatDateTime(access.accessed_at)),
        access.timezone ? '<div class="muted">' + escapeHtml(access.timezone) + "</div>" : "",
        "</td>",
        '<td><a class="page-link" href="' + escapeHtml(pagePath) + '" target="_blank" rel="noopener noreferrer">' +
          escapeHtml(pageTitle) + "</a>",
        '<div class="muted">' + escapeHtml(pagePath) + "</div></td>",
        "<td>" + locationHtml + "</td>",
        "</tr>"
      ].join("");
    }).join("");

    message.hidden = true;
    tableWrap.hidden = false;
  }

  async function loadStudents() {
    const response = await Auth.getClient().rpc("get_teacher_students");
    if (response.error) throw response.error;
    renderStudents(response.data || []);
  }

  async function loadAccesses() {
    const refreshButton = document.getElementById("refreshAccesses");
    const message = document.getElementById("accessMessage");
    const tableWrap = document.getElementById("accessTableWrap");
    const days = Number(document.getElementById("periodFilter").value || 30);
    const userId = document.getElementById("studentFilter").value || null;

    refreshButton.disabled = true;
    message.hidden = false;
    message.className = "empty";
    message.textContent = "Carregando acessos...";
    tableWrap.hidden = true;

    try {
      const response = await Auth.getClient().rpc("get_teacher_student_accesses", {
        target_days: days,
        target_user_id: userId
      });
      if (response.error) throw response.error;
      renderAccesses(response.data || []);
      setStatus("Professor autenticado: " + currentSession.user.email + ".");
    } catch (error) {
      renderSummary([]);
      message.hidden = false;
      message.className = "error";
      message.textContent = "Não foi possível carregar os acessos. Execute o arquivo supabase_acessos_alunos.sql no Supabase e tente novamente. Detalhe: " + (error.message || "erro desconhecido");
      setStatus("O painel ainda não está configurado no Supabase.", true);
    } finally {
      refreshButton.disabled = false;
    }
  }

  async function initializeDashboard() {
    const ready = await waitForResources();
    const content = document.getElementById("dashboardContent");

    if (!ready) {
      setStatus("Não foi possível carregar a autenticação. Atualize a página ou limpe o cache.", true);
      document.body.classList.remove("auth-checking");
      return;
    }

    currentSession = await Auth.getSession();
    if (!currentSession || !currentSession.user) {
      window.location.href = "/login.html?next=" + encodeURIComponent("acessos_dos_alunos.html");
      return;
    }

    try {
      const adminResponse = await Auth.getClient().rpc("is_teacher_admin");
      if (adminResponse.error) throw adminResponse.error;
      if (adminResponse.data !== true) {
        setStatus("Acesso negado. Esta página é exclusiva do professor.", true);
        document.body.classList.remove("auth-checking");
        return;
      }

      content.hidden = false;
      document.body.classList.remove("auth-checking");
      setStatus("Professor autenticado: " + currentSession.user.email + ".");

      await loadStudents();
      await loadAccesses();
    } catch (error) {
      setStatus("Não foi possível confirmar as credenciais administrativas.", true);
      document.body.classList.remove("auth-checking");
    }
  }

  document.getElementById("refreshAccesses").addEventListener("click", loadAccesses);
  document.getElementById("studentFilter").addEventListener("change", loadAccesses);
  document.getElementById("periodFilter").addEventListener("change", loadAccesses);

  initializeDashboard();
})();
