function addCopyButtonCallbacks() {
  for (const el of document.getElementsByTagName("pre")) {
    const button = document.createElement("button");
    button.classList.add("copy-button", "fas", "fa-copy");
    el.appendChild(button);

    button.addEventListener("click", function () {
      navigator.clipboard.writeText(el.innerText).then(
        function () {
          button.classList.add("success", "fa-check");
          button.classList.remove("fa-copy");
        },
        function () {
          button.classList.add("error", "fa-times");
          button.classList.remove("fa-copy");
        }
      );

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
