(function () {
  "use strict";

  function isSafeUrl(value) {
    if (!value) return false;
    if (value.startsWith("#")) return true;
    if (value.startsWith("/")) return !value.startsWith("//") && !value.startsWith("/\\");

    try {
      const parsed = new URL(value, window.location.origin);
      return parsed.protocol === "https:" || parsed.protocol === "http:";
    } catch (error) {
      return false;
    }
  }

  function applyContent(item) {
    const selector = '[data-cms-key="' + CSS.escape(item.key) + '"]';
    const elements = document.querySelectorAll(selector);

    elements.forEach(function (element) {
      const value = typeof item.value === "string" ? item.value : "";
      const attribute = element.dataset.cmsAttr || "text";

      if (attribute === "text") {
        element.textContent = value;
        return;
      }

      if (!value || !isSafeUrl(value)) return;

      if (attribute === "href") {
        element.setAttribute("href", value);
      } else if (attribute === "src") {
        element.setAttribute("src", value);
        element.hidden = false;
      } else if (attribute === "background-image") {
        element.style.backgroundImage = 'linear-gradient(rgba(15, 23, 42, 0.12), rgba(15, 23, 42, 0.42)), url("' + value.replace(/["\\]/g, "") + '")';
        element.hidden = false;
      }
    });
  }

  async function loadCmsContent() {
    const pageSlug = document.body.dataset.cmsPage;
    const config = window.SUPABASE_CONFIG;

    if (!pageSlug || !config || !config.url || !config.anonKey || !window.supabase) return;

    try {
      const client = window.supabase.createClient(config.url, config.anonKey, {
        auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
      });
      const response = await client
        .from("site_content")
        .select("key,value,content_type")
        .eq("page_slug", pageSlug)
        .order("sort_order", { ascending: true });

      if (response.error) throw response.error;
      (response.data || []).forEach(applyContent);
      document.documentElement.dataset.cmsReady = "true";
    } catch (error) {
      console.warn("CMS indisponível; mantendo o conteúdo padrão da página.", error);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", loadCmsContent, { once: true });
  } else {
    loadCmsContent();
  }
})();
