function addCopyButtonCallbacks() {
  for (const el of document.getElementsByTagName("pre")) {
    const button = document.createElement("button");
    button.classList.add("copy-button", "fa-solid", "fa-copy");
    button.setAttribute("aria-label", "Copy this code block");
    button.setAttribute("title", "Copy");

    el.appendChild(button);

    const success = function () {
      button.classList.add("success", "fa-check");
      button.classList.remove("fa-copy");
    };

    const failure = function () {
      button.classList.add("error", "fa-xmark");
      button.classList.remove("fa-copy");
    };

    button.addEventListener("click", function () {
      copyToClipboard(el.innerText).then(success, failure);

      setTimeout(function () {
        button.classList.add("fa-copy");
        button.classList.remove("success", "fa-check", "fa-xmark");
      }, 5000);
    });
  }
}

function copyToClipboard(text) {
  // clipboard API is only available in secure contexts
  if (window.navigator && window.navigator.clipboard) {
    return window.navigator.clipboard.writeText(text);
  } else {
    return new Promise(function (resolve, reject) {
      try {
        const el = document.createElement("textarea");
        el.textContent = text;
        el.style.position = "fixed";
        el.style.opacity = 0;
        document.body.appendChild(el);
        el.select();
        document.execCommand("copy");

        resolve();
      } catch (err) {
        reject(err);
      } finally {
        document.body.removeChild(el);
      }
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", addCopyButtonCallbacks);
} else {
  addCopyButtonCallbacks();
}
