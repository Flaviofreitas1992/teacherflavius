(function () {
  if (window.__studentAccessTrackerLoaded) return;
  window.__studentAccessTrackerLoaded = true;

  const DEFAULT_PREFERENCE = {
    consent_decided: false,
    location_consent: false,
    consented_at: null,
    revoked_at: null
  };

  let lastAccessId = null;
  let trackingStarted = false;

  function sleep(ms) {
    return new Promise(function (resolve) { setTimeout(resolve, ms); });
  }

  async function waitForAuth() {
    for (let attempt = 0; attempt < 20; attempt++) {
      if (window.Auth && Auth.getClient && Auth.getSession) return true;
      await sleep(150);
    }
    return !!(window.Auth && Auth.getClient && Auth.getSession);
  }

  function getTimezone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone || "";
    } catch (error) {
      return "";
    }
  }

  function normalizePreference(value) {
    return Object.assign({}, DEFAULT_PREFERENCE, value || {});
  }

  async function getPreference() {
    if (!(await waitForAuth())) return normalizePreference();
    const client = Auth.getClient();
    if (!client) return normalizePreference();

    const response = await client.rpc("get_my_student_access_preference");
    if (response.error) throw response.error;
    return normalizePreference(response.data);
  }

  function getApproximateLocation() {
    return new Promise(function (resolve) {
      if (!window.isSecureContext || !navigator.geolocation) {
        resolve({ status: "unavailable", latitude: null, longitude: null, accuracy: null });
        return;
      }

      navigator.geolocation.getCurrentPosition(
        function (position) {
          resolve({
            status: "granted",
            latitude: Math.round(position.coords.latitude * 100) / 100,
            longitude: Math.round(position.coords.longitude * 100) / 100,
            accuracy: Math.round(position.coords.accuracy || 0)
          });
        },
        function (error) {
          let status = "error";
          if (error && error.code === 1) status = "denied";
          if (error && error.code === 2) status = "unavailable";
          resolve({ status: status, latitude: null, longitude: null, accuracy: null });
        },
        {
          enableHighAccuracy: false,
          timeout: 6000,
          maximumAge: 15 * 60 * 1000
        }
      );
    });
  }

  function locationRpcPayload(location) {
    return {
      target_latitude: location && location.latitude != null ? location.latitude : null,
      target_longitude: location && location.longitude != null ? location.longitude : null,
      target_accuracy: location && location.accuracy != null ? location.accuracy : null,
      target_location_status: location && location.status ? location.status : "not_shared"
    };
  }

  async function updateAccessLocation(accessId, location) {
    if (!accessId || !Auth.getClient()) return null;
    const payload = Object.assign(
      { target_access_id: accessId },
      locationRpcPayload(location)
    );
    const response = await Auth.getClient().rpc("update_my_student_access_location", payload);
    if (response.error) throw response.error;
    return response.data;
  }

  function removeConsentBanner() {
    const banner = document.getElementById("student-access-privacy-banner");
    if (banner) banner.remove();
  }

  function injectConsentStyles() {
    if (document.getElementById("student-access-privacy-styles")) return;
    const style = document.createElement("style");
    style.id = "student-access-privacy-styles";
    style.textContent = [
      "#student-access-privacy-banner{position:fixed;left:16px;right:16px;bottom:16px;z-index:30000;max-width:780px;margin:0 auto;padding:18px;border-radius:16px;background:#111827;border:1px solid rgba(129,140,248,.55);box-shadow:0 18px 50px rgba(0,0,0,.45);color:#e5e7eb;font-family:Georgia,serif;line-height:1.55}",
      "#student-access-privacy-banner strong{display:block;color:#fff;font-size:17px;margin-bottom:6px}",
      "#student-access-privacy-banner p{margin:0;color:#cbd5e1;font-size:13px}",
      "#student-access-privacy-banner .privacy-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}",
      "#student-access-privacy-banner button,#student-access-privacy-banner a{border-radius:10px;padding:10px 14px;font:700 12px Georgia,serif;cursor:pointer;text-decoration:none}",
      "#student-access-privacy-banner .privacy-allow{border:0;background:linear-gradient(90deg,#818cf8,#a78bfa);color:#fff}",
      "#student-access-privacy-banner .privacy-decline,#student-access-privacy-banner a{border:1px solid rgba(203,213,225,.28);background:rgba(255,255,255,.05);color:#cbd5e1}",
      "#student-access-privacy-banner button:disabled{opacity:.55;cursor:wait}"
    ].join("");
    document.head.appendChild(style);
  }

  function showConsentBanner() {
    if (document.getElementById("student-access-privacy-banner") || !document.body) return;
    injectConsentStyles();

    const banner = document.createElement("aside");
    banner.id = "student-access-privacy-banner";
    banner.setAttribute("role", "dialog");
    banner.setAttribute("aria-live", "polite");
    banner.setAttribute("aria-label", "Preferência de localização");
    banner.innerHTML = [
      "<strong>Privacidade dos acessos</strong>",
      "<p>O site registra as páginas acessadas, a data e a hora por até 90 dias. Não armazenamos seu IP nem os parâmetros da URL. Você permite compartilhar também sua localização aproximada com o professor? Essa permissão é opcional e pode ser revogada em Meu Perfil.</p>",
      '<div class="privacy-actions">',
      '<button type="button" class="privacy-allow">PERMITIR LOCALIZAÇÃO</button>',
      '<button type="button" class="privacy-decline">NÃO COMPARTILHAR</button>',
      '<a href="/perfil.html">VER PREFERÊNCIAS</a>',
      "</div>"
    ].join("");

    const allowButton = banner.querySelector(".privacy-allow");
    const declineButton = banner.querySelector(".privacy-decline");

    allowButton.addEventListener("click", async function () {
      allowButton.disabled = true;
      declineButton.disabled = true;
      try {
        await setLocationConsent(true);
        removeConsentBanner();
      } catch (error) {
        allowButton.disabled = false;
        declineButton.disabled = false;
        console.warn("Não foi possível salvar a preferência de localização:", error.message);
      }
    });

    declineButton.addEventListener("click", async function () {
      allowButton.disabled = true;
      declineButton.disabled = true;
      try {
        await setLocationConsent(false);
        removeConsentBanner();
      } catch (error) {
        allowButton.disabled = false;
        declineButton.disabled = false;
        console.warn("Não foi possível salvar a preferência de localização:", error.message);
      }
    });

    document.body.appendChild(banner);
  }

  async function setLocationConsent(consent) {
    if (!(await waitForAuth()) || !Auth.getClient()) {
      throw new Error("Autenticação indisponível.");
    }

    // A solicitação ao navegador começa imediatamente após o clique do aluno.
    const locationPromise = consent
      ? getApproximateLocation()
      : Promise.resolve({ status: "not_shared", latitude: null, longitude: null, accuracy: null });

    const response = await Auth.getClient().rpc(
      "save_my_student_location_preference",
      { target_consent: !!consent }
    );
    if (response.error) throw response.error;

    const location = await locationPromise;
    if (lastAccessId) await updateAccessLocation(lastAccessId, location);

    window.dispatchEvent(new CustomEvent("student-access-preference-changed", {
      detail: {
        preference: normalizePreference(response.data),
        location_status: location.status
      }
    }));

    return {
      preference: normalizePreference(response.data),
      location_status: location.status
    };
  }

  async function logCurrentPage() {
    if (!(await waitForAuth())) return null;

    const session = await Auth.getSession();
    const client = Auth.getClient();
    if (!session || !session.user || !client) return null;

    let preference;
    try {
      preference = await getPreference();
    } catch (error) {
      console.warn("O rastreamento de acessos ainda não foi configurado no Supabase:", error.message);
      return null;
    }

    let location = { status: "not_shared", latitude: null, longitude: null, accuracy: null };
    if (preference.location_consent === true) {
      location = await getApproximateLocation();
    }

    const payload = Object.assign({
      target_page_path: window.location.pathname || "/",
      target_page_title: document.title || "",
      target_timezone: getTimezone()
    }, locationRpcPayload(location));

    const response = await client.rpc("log_student_page_access", payload);
    if (response.error) {
      console.warn("Não foi possível registrar o acesso:", response.error.message);
      return null;
    }

    const result = response.data || {};
    if (result.logged === true) {
      lastAccessId = result.access_id || null;
      if (preference.consent_decided !== true) showConsentBanner();
    }

    return result;
  }

  async function startTracking() {
    if (trackingStarted) return;
    trackingStarted = true;
    await logCurrentPage();
  }

  window.StudentAccessTracker = {
    getPreference: getPreference,
    setLocationConsent: setLocationConsent,
    logCurrentPage: logCurrentPage
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", startTracking, { once: true });
  } else {
    startTracking();
  }

  window.addEventListener("pageshow", function (event) {
    if (event.persisted) logCurrentPage();
  });
})();
