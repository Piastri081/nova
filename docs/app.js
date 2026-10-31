(function () {
  const configured = (window.NOVA_REPO || "").replace(/^\/+|\/+$/g, "");
  const version = window.NOVA_VERSION || "1.0.0";

  function detectRepo() {
    if (configured && configured !== "your-username/nova") {
      return configured;
    }

    const host = window.location.hostname;
    const parts = window.location.pathname.split("/").filter(Boolean);

    if (host.endsWith(".github.io") && parts.length > 0) {
      return host.split(".")[0] + "/" + parts[0];
    }

    return "your-username/nova";
  }

  const repo = detectRepo();
  const base = "https://github.com/" + repo;
  const isPlaceholder = repo === "your-username/nova";

  document.querySelectorAll("[data-version]").forEach((node) => {
    node.textContent = version;
  });

  document.querySelectorAll("[data-repo-link]").forEach((node) => {
    node.href = base;
  });

  document.querySelectorAll("[data-releases-link]").forEach((node) => {
    node.href = base + "/releases";
  });

  document.querySelectorAll("[data-ipa-link]").forEach((node) => {
    node.href = base + "/releases/latest/download/Nova.ipa";
  });

  const note = document.querySelector("[data-repo-note]");
  if (note && !isPlaceholder) {
    note.remove();
  }
})();
