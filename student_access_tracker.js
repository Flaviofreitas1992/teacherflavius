(function () {
  if (window.__studentAccessTrackerLoaded) return;
  window.__studentAccessTrackerLoaded = true;

  let trackingStarted = false;
  let googleLinkPromptChecked = false;

  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  async function waitForAuth() {
    for (let attempt = 0; attempt < 20; attempt++) {
      if (
        window.Auth &&
        Auth.getClient &&
        Auth.getSession &&
        Auth.getProfile &&
        Auth.getUserIdentities &&
        Auth.linkGoogleIdentity
      ) return true;
      await sleep(150);
    }
    return !!(
      window.Auth &&
      Auth.getClient &&
      Auth.getSession &&
      Auth.getProfile &&
      Auth.getUserIdentities &&
      Auth.linkGoogleIdentity
    );
  }

  function getTimezone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone || "";
    } catch (error) {
      return "";
    }
  }

  function isOnExcludedGooglePromptPage() {
    const path = window.location.pathname || "/";
    return path === "/login/" ||
      path.endsWith("/login.html") ||
      path === "/complete-cadastro/" ||
      path.endsWith("/complete-cadastro.html");
  }

  function installGoogleLinkPromptStyles() {
    if (document.getElementById("teacher-google-link-prompt-styles")) return;

    const style = document.createElement("style");
    style.id = "teacher-google-link-prompt-styles";
    style.textContent = [
      ".teacher-google-link-overlay{position:fixed;inset:0;z-index:2147483000;display:flex;align-items:center;justify-content:center;padding:20px;background:rgba(2,6,23,.82);backdrop-filter:blur(8px)}",
      ".teacher-google-link-modal{width:min(100%,460px);padding:30px 26px;border:1px solid rgba(129,140,248,.38);border-radius:20px;background:linear-gradient(145deg,#111827,#1e1b4b);box-shadow:0 28px 80px rgba(0,0,0,.48);font-family:Georgia,serif;text-align:center;color:#f8fafc}",
      ".teacher-google-link-badge{display:inline-block;margin-bottom:18px;padding:5px 13px;border-radius:999px;background:linear-gradient(90deg,#818cf8,#a78bfa);font:700 11px monospace;letter-spacing:2px;color:#fff}",
      ".teacher-google-link-message{margin:0 0 22px;color:#f1f5f9;font-size:20px;line-height:1.55}",
      ".teacher-google-link-button{width:100%;display:inline-flex;align-items:center;justify-content:center;gap:10px;padding:14px 18px;border:0;border-radius:12px;background:#fff;color:#1f2937;font:700 15px Georgia,serif;cursor:pointer}",
      ".teacher-google-link-button:hover{background:#f8fafc}",
      ".teacher-google-link-button:disabled{opacity:.65;cursor:wait}",
      ".teacher-google-link-g{font-family:Arial,sans-serif;font-size:20px;font-weight:700}",
      ".teacher-google-link-error{min-height:18px;margin-top:12px;color:#fca5a5;font-size:13px;line-height:1.45}",
      "@media(max-width:520px){.teacher-google-link-modal{padding:25px 20px}.teacher-google-link-message{font-size:18px}}"
    ].join("");
    document.head.appendChild(style);
  }

  function showGoogleLinkPrompt() {
    if (!document.body || document.getElementById("teacherGoogleLinkPrompt")) return;

    installGoogleLinkPromptStyles();

    const overlay = document.createElement("div");
    overlay.id = "teacherGoogleLinkPrompt";
    overlay.className = "teacher-google-link-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-labelledby", "teacherGoogleLinkPromptMessage");
    overlay.innerHTML = [
      '<div class="teacher-google-link-modal">',
      '<div class="teacher-google-link-badge">TEACHER FLÁVIO</div>',
      '<p id="teacherGoogleLinkPromptMessage" class="teacher-google-link-message">A partir de hoje o seu acesso ao site será feito por meio da sua conta Google.</p>',
      '<button id="teacherGoogleLinkButton" class="teacher-google-link-button" type="button"><span class="teacher-google-link-g">G</span> VINCULAR CONTA GOOGLE</button>',
      '<div id="teacherGoogleLinkError" class="teacher-google-link-error" role="alert"></div>',
      '</div>'
    ].join("");

    document.body.appendChild(overlay);
    document.documentElement.style.overflow = "hidden";

    const button = document.getElementById("teacherGoogleLinkButton");
    const errorBox = document.getElementById("teacherGoogleLinkError");
    button.focus();

    button.addEventListener("click", async function () {
      button.disabled = true;
      button.textContent = "ABRINDO GOOGLE...";
      errorBox.textContent = "";

      try {
        await Auth.linkGoogleIdentity();
      } catch (error) {
        button.disabled = false;
        button.innerHTML = '<span class="teacher-google-link-g">G</span> VINCULAR CONTA GOOGLE';
        errorBox.textContent = error.message || "Não foi possível iniciar a vinculação com o Google. Tente novamente.";
      }
    });
  }

  async function maybeShowGoogleLinkPrompt() {
    if (googleLinkPromptChecked || isOnExcludedGooglePromptPage()) return;
    googleLinkPromptChecked = true;

    if (!(await waitForAuth())) return;

    try {
      const session = await Auth.getSession();
      const client = Auth.getClient();
      if (!session || !session.user || !client) return;

      const adminResponse = await client.rpc("is_teacher_admin");
      if (adminResponse.error || adminResponse.data === true) return;

      const profile = await Auth.getProfile();
      if (!profile || profile.enrolled !== true || profile.profile_completed !== true) return;

      const identities = await Auth.getUserIdentities();
      const hasGoogle = identities.some(function (identity) {
        return identity && identity.provider === "google";
      });
      if (hasGoogle) return;

      showGoogleLinkPrompt();
    } catch (error) {
      console.warn("Não foi possível verificar a vinculação com o Google:", error && error.message ? error.message : error);
    }
  }

  async function logCurrentPage() {
    if (!(await waitForAuth())) return null;

    const session = await Auth.getSession();
    const client = Auth.getClient();
    if (!session || !session.user || !client) return null;

    const response = await client.rpc("log_student_page_access", {
      target_page_path: window.location.pathname || "/",
      target_page_title: document.title || "",
      target_timezone: getTimezone()
    });

    if (response.error) {
      console.warn("Não foi possível registrar o acesso:", response.error.message);
      return null;
    }

    return response.data || null;
  }

  async function startTracking() {
    if (trackingStarted) return;
    trackingStarted = true;
    await logCurrentPage();
  }

  function startStudentSessionFeatures() {
    startTracking();
    maybeShowGoogleLinkPrompt();
  }

  window.StudentAccessTracker = {
    logCurrentPage: logCurrentPage,
    checkGoogleLinkPrompt: maybeShowGoogleLinkPrompt
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startStudentSessionFeatures, { once: true });
  } else {
    startStudentSessionFeatures();
  }

  window.addEventListener("pageshow", function (event) {
    if (event.persisted) {
      googleLinkPromptChecked = false;
      logCurrentPage();
      maybeShowGoogleLinkPrompt();
    }
  });
})();
