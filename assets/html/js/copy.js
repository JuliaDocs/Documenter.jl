function addCopyButtonCallbacks() {
  for (const el of document.getElementsByTagName("pre")) {
    const button = document.createElement("button");
    button.classList.add("copy-button", "fas", "fa-copy");
    el.appendChild(button);

    const success = function () {
      button.classList.add("success", "fa-check");
      button.classList.remove("fa-copy");
    };

    const failure = function () {
      button.classList.add("error", "fa-times");
      button.classList.remove("fa-copy");
    };

    button.addEventListener("click", function () {
      if (window.navigator && window.navigator.clipboard && window.navigator.clipboard.writeText) {
        window.navigator.clipboard.writeText(el.innerText).then(success, failure);
      } else {
        failure()
      }

      setTimeout(function () {
        button.classList.add("fa-copy");
        button.classList.remove("success", "fa-check", "fa-times");
      }, 5000);
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", addCopyButtonCallbacks);
} else {
  addCopyButtonCallbacks();
}
