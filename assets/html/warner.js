function maybeAddWarning() {
  // DOCUMENTER_NEWEST is defined in versions.js, DOCUMENTER_CURRENT_VERSION and DOCUMENTER_STABLE
  // in siteinfo.js. DOCUMENTER_IS_DEV_VERSION is optional and defined in siteinfo.js.
  // If the required variables are undefined something went horribly wrong, so we abort.
  if (
    window.DOCUMENTER_NEWEST === undefined ||
    window.DOCUMENTER_CURRENT_VERSION === undefined ||
    window.DOCUMENTER_STABLE === undefined
  ) {
    return;
  }

  // Current version is not a version number, so we can't tell if it's the newest version. Abort.
  if (!/v(\d+\.)*\d+/.test(window.DOCUMENTER_CURRENT_VERSION)) {
    return;
  }

  // Current version is newest version, so no need to add a warning.
  if (window.DOCUMENTER_NEWEST === window.DOCUMENTER_CURRENT_VERSION) {
    return;
  }

  // Add a noindex meta tag (unless one exists) so that search engines don't index this version of the docs.
  if (document.body.querySelector('meta[name="robots"]') === null) {
    const meta = document.createElement("meta");
    meta.name = "robots";
    meta.content = "noindex";

    document.getElementsByTagName("head")[0].appendChild(meta);
  }

  const div = document.createElement("div");
  // Base class is added by default
  div.classList.add("warning-overlay-base");
  const closer = document.createElement("button");
  closer.classList.add("outdated-warning-closer", "delete");
  closer.addEventListener("click", function () {
    document.body.removeChild(div);
  });
  const href = window.documenterBaseURL + "/../" + window.DOCUMENTER_STABLE;

  // Try to stay on the same page when linking to the stable version
  var current_hash = window.location.hash;
  var page_path = "";
  var target_url = href;

  if (typeof window.documenterBaseURL !== "undefined") {
    var current_page = window.location.pathname;
    var base_url_absolute = new URL(
      window.documenterBaseURL,
      window.location.href,
    ).pathname;
    if (!base_url_absolute.endsWith("/")) {
      base_url_absolute = base_url_absolute + "/";
    }
    if (current_page.startsWith(base_url_absolute)) {
      page_path = current_page.substring(base_url_absolute.length);
    }
    if (page_path && page_path !== "" && page_path !== "index.html") {
      var stable_base = href;
      if (stable_base.endsWith("/")) {
        stable_base = stable_base.slice(0, -1);
      }
      target_url = stable_base + "/" + page_path;
    }
  }

  // Determine if this is a development version or an older release
  let warningMessage = "";
  if (window.DOCUMENTER_IS_DEV_VERSION === true) {
    div.classList.add("dev-warning-overlay");
    warningMessage =
      "This documentation is for the <strong>development version</strong> and may contain unstable or unreleased features.<br>";
  } else {
    div.classList.add("outdated-warning-overlay");
    warningMessage =
      "This documentation is for an <strong>older version</strong> that may be missing recent changes.<br>";
  }

  // Create the link element with same-page navigation
  const link = document.createElement("a");
  link.href = target_url + current_hash;
  link.textContent =
    "Click here to go to the documentation for the latest stable release.";

  // If we're trying to stay on the same page, verify it exists first
  if (page_path && page_path !== "" && page_path !== "index.html") {
    link.addEventListener("click", function (e) {
      e.preventDefault();
      fetch(target_url, { method: "HEAD" })
        .then(function (response) {
          if (response.ok) {
            window.location.href = target_url + current_hash;
          } else {
            window.location.href = href;
          }
        })
        .catch(function () {
          window.location.href = href;
        });
    });
  }

  div.innerHTML = warningMessage;
  div.appendChild(link);
  div.appendChild(closer);
  document.body.appendChild(div);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", maybeAddWarning);
} else {
  maybeAddWarning();
}
