(function () {
  "use strict";

  const state = {
    client: null,
    session: null,
    items: [],
    activePage: ""
  };

  const sectionNames = {
    cabecalho: "Cabeçalho",
    card_aluno: "Card do aluno",
    card_visitante: "Card de visitante",
    main: "Conteúdo principal",
    menu: "Menu",
    navegacao: "Navegação",
    hero: "Apresentação",
    nova_turma: "Nova turma",
    beneficios: "Benefícios",
    disponibilidade: "Disponibilidade",
    investimento: "Investimento",
    professor: "Professor",
    redes_sociais: "Redes sociais",
    roteiro: "Roteiro de estudos",
    gramatica: "Gramática",
    tarefas: "Tarefas para casa",
    turma_guia: "Sua turma",
    reposicao: "Reposição de aulas",
    anotacoes: "Anotações das aulas",
    feriados: "Feriados",
    cancelamentos: "Cancelamento de aulas",
    transferencia: "Transferência de turma",
    encerramento: "Substituição e cancelamento"
  };

  const pageNames = {
    home: "Página inicial",
    aluno: "Portal do aluno",
    quero_conhecer: "Conheça as aulas",
    guia_estudante: "Guia do estudante"
  };
  const pageOrder = ["home", "aluno", "quero_conhecer", "guia_estudante"];

  function byId(id) { return document.getElementById(id); }
  function sleep(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }

  function showMessage(message, type) {
    const element = byId("cmsMessage");
    element.textContent = message || "";
    element.className = "cms-message" + (type ? " " + type : "");
  }

  function setBusy(isBusy) {
    byId("cmsEditor").setAttribute("aria-busy", String(isBusy));
    byId("cmsSaveButton").disabled = isBusy;
    byId("cmsReloadButton").disabled = isBusy;
    byId("cmsPageSelect").disabled = isBusy;
  }

  async function waitForResources() {
    for (let attempt = 0; attempt < 12; attempt += 1) {
      if (window.Auth && window.SUPABASE_CONFIG && Auth.isConfigured()) return true;
      await sleep(150);
    }
    return false;
  }

  function redirectToLogin() {
    window.location.href = "/login/?next=" + encodeURIComponent("/cms/");
  }

  function normalizeUrl(value) {
    const trimmed = value.trim();
    if (!trimmed) return "";
    if (trimmed.startsWith("#")) return trimmed;
    if (trimmed.startsWith("/") && !trimmed.startsWith("//") && !trimmed.startsWith("/\\")) return trimmed;

    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      throw new Error("Os links devem começar com https://, http:// ou /. ");
    }
    return parsed.toString();
  }

  function createTextControl(item) {
    const control = item.content_type === "textarea"
      ? document.createElement("textarea")
      : document.createElement("input");

    if (control.tagName === "INPUT") control.type = item.content_type === "url" ? "url" : "text";
    control.value = item.value || "";
    control.dataset.contentKey = item.key;
    control.dataset.contentType = item.content_type;
    control.autocomplete = "off";
    return control;
  }

  function createImageControl(item) {
    const wrapper = document.createElement("div");
    wrapper.className = "image-control";

    const inputs = document.createElement("div");
    const urlInput = document.createElement("input");
    urlInput.type = "url";
    urlInput.value = item.value || "";
    urlInput.placeholder = "https://...";
    urlInput.dataset.contentKey = item.key;
    urlInput.dataset.contentType = item.content_type;

    const fileInput = document.createElement("input");
    fileInput.type = "file";
    fileInput.accept = "image/jpeg,image/png,image/webp,image/gif";
    fileInput.className = "file-input";
    fileInput.dataset.uploadFor = item.key;
    fileInput.setAttribute("aria-label", "Enviar nova imagem para " + item.label);
    fileInput.addEventListener("change", function () {
      const file = fileInput.files && fileInput.files[0];
      if (file) preview.src = URL.createObjectURL(file);
    });

    inputs.append(urlInput, fileInput);

    const preview = document.createElement("img");
    preview.className = "image-preview";
    preview.alt = "Prévia de " + item.label;
    if (item.value) preview.src = item.value;

    wrapper.append(inputs, preview);
    return wrapper;
  }

  function renderEditor() {
    const editor = byId("cmsEditor");
    editor.replaceChildren();
    const pageItems = state.items.filter(function (item) { return item.page_slug === state.activePage; });

    if (!pageItems.length) {
      const empty = document.createElement("div");
      empty.className = "cms-empty";
      empty.textContent = "Nenhum campo foi configurado para esta página.";
      editor.appendChild(empty);
      return;
    }

    const sections = new Map();
    pageItems.forEach(function (item) {
      if (!sections.has(item.section_slug)) sections.set(item.section_slug, []);
      sections.get(item.section_slug).push(item);
    });

    sections.forEach(function (items, sectionSlug) {
      const section = document.createElement("section");
      section.className = "cms-section";

      const title = document.createElement("h2");
      title.textContent = sectionNames[sectionSlug] || sectionSlug.replace(/_/g, " ");

      const fields = document.createElement("div");
      fields.className = "cms-fields";

      items.forEach(function (item) {
        const field = document.createElement("label");
        field.className = "cms-field" + (item.content_type === "textarea" || item.content_type === "image" ? " full" : "");

        const label = document.createElement("span");
        label.textContent = item.label;
        const hint = document.createElement("small");
        hint.textContent = " " + item.key;
        label.appendChild(hint);

        field.append(label, item.content_type === "image" ? createImageControl(item) : createTextControl(item));
        fields.appendChild(field);
      });

      section.append(title, fields);
      editor.appendChild(section);
    });
  }

  function renderPageSelect() {
    const select = byId("cmsPageSelect");
    const pages = Array.from(new Set(state.items.map(function (item) { return item.page_slug; }))).sort(function (a, b) {
      const aIndex = pageOrder.indexOf(a);
      const bIndex = pageOrder.indexOf(b);
      if (aIndex === -1 && bIndex === -1) return a.localeCompare(b, "pt-BR");
      if (aIndex === -1) return 1;
      if (bIndex === -1) return -1;
      return aIndex - bIndex;
    });
    select.replaceChildren();

    pages.forEach(function (page) {
      const option = document.createElement("option");
      option.value = page;
      option.textContent = pageNames[page] || page;
      select.appendChild(option);
    });

    state.activePage = state.activePage && pages.includes(state.activePage) ? state.activePage : (pages[0] || "");
    select.value = state.activePage;
  }

  async function loadContent() {
    setBusy(true);
    showMessage("Carregando conteúdo...");

    const response = await state.client
      .from("site_content")
      .select("key,page_slug,section_slug,label,content_type,value,sort_order,updated_at")
      .order("page_slug", { ascending: true })
      .order("sort_order", { ascending: true });

    if (response.error) {
      throw new Error(response.error.message.includes("site_content")
        ? "O banco do CMS ainda não foi instalado. Execute supabase_cms.sql no Supabase."
        : response.error.message);
    }

    state.items = response.data || [];
    renderPageSelect();
    renderEditor();
    showMessage("Conteúdo carregado. As alterações só aparecem no site após clicar em Salvar e publicar.");
    setBusy(false);
  }

  function extensionFor(file) {
    const byMime = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif" };
    return byMime[file.type] || "img";
  }

  async function uploadImage(input) {
    const file = input.files && input.files[0];
    if (!file) return null;
    if (!file.type.startsWith("image/")) throw new Error("Selecione um arquivo de imagem válido.");
    if (file.size > 5 * 1024 * 1024) throw new Error("Cada imagem deve ter no máximo 5 MB.");

    const key = input.dataset.uploadFor;
    const safeKey = key.replace(/[^a-z0-9_-]+/gi, "-");
    const uniqueId = window.crypto && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2);
    const path = state.activePage + "/" + safeKey + "/" + Date.now() + "-" + uniqueId + "." + extensionFor(file);
    const upload = await state.client.storage.from("cms-media").upload(path, file, {
      cacheControl: "3600",
      contentType: file.type,
      upsert: false
    });

    if (upload.error) throw upload.error;
    const publicUrl = state.client.storage.from("cms-media").getPublicUrl(path);
    return publicUrl.data.publicUrl;
  }

  async function saveContent() {
    setBusy(true);
    showMessage("Enviando imagens e publicando alterações...");

    try {
      const uploadInputs = Array.from(document.querySelectorAll("[data-upload-for]"));
      for (const input of uploadInputs) {
        const uploadedUrl = await uploadImage(input);
        if (uploadedUrl) {
          const urlInput = document.querySelector('[data-content-key="' + CSS.escape(input.dataset.uploadFor) + '"]');
          urlInput.value = uploadedUrl;
        }
      }

      const existingByKey = new Map(state.items.map(function (item) { return [item.key, item]; }));
      const controls = Array.from(document.querySelectorAll("[data-content-key]"));
      const now = new Date().toISOString();
      const payload = controls.map(function (control) {
        const item = existingByKey.get(control.dataset.contentKey);
        let value = control.value.trim();
        if (control.dataset.contentType === "url" || control.dataset.contentType === "image") value = normalizeUrl(value);

        return {
          key: item.key,
          page_slug: item.page_slug,
          section_slug: item.section_slug,
          label: item.label,
          content_type: item.content_type,
          value: value,
          sort_order: item.sort_order,
          updated_at: now,
          updated_by: state.session.user.id
        };
      });

      const response = await state.client.from("site_content").upsert(payload, { onConflict: "key" });
      if (response.error) throw response.error;

      await loadContent();
      showMessage("Conteúdo publicado com sucesso. A HOME já pode ser atualizada no navegador.", "success");
    } catch (error) {
      showMessage(error.message || "Não foi possível salvar o conteúdo.", "error");
      setBusy(false);
    }
  }

  async function initialize() {
    const ready = await waitForResources();
    if (!ready) {
      showMessage("Não foi possível carregar a autenticação. Atualize a página ou limpe o cache.", "error");
      document.body.classList.remove("auth-checking");
      return;
    }

    state.client = Auth.getClient();
    state.session = await Auth.getSession();
    if (!state.session || !state.session.user) {
      redirectToLogin();
      return;
    }

    const adminCheck = await state.client.rpc("is_teacher_admin");
    if (adminCheck.error || adminCheck.data !== true) {
      byId("cmsAuthStatus").textContent = "Acesso negado. Esta área é exclusiva dos administradores autorizados.";
      showMessage("Sua conta não possui permissão para alterar o site.", "error");
      document.body.classList.remove("auth-checking");
      return;
    }

    byId("cmsAuthStatus").textContent = "Administrador autenticado: " + state.session.user.email;
    document.body.classList.remove("auth-checking");

    byId("cmsSaveButton").addEventListener("click", saveContent);
    byId("cmsReloadButton").addEventListener("click", function () { loadContent().catch(handleLoadError); });
    byId("cmsPageSelect").addEventListener("change", function (event) {
      state.activePage = event.target.value;
      renderEditor();
    });

    await loadContent();
  }

  function handleLoadError(error) {
    showMessage(error.message || "Não foi possível carregar o CMS.", "error");
    setBusy(true);
  }

  initialize().catch(handleLoadError);
})();
