function unescape_str(str) {
  return str.replace(/\\(.)/g, function (match, val) {
    let out;
    switch (val) {
      case "a":
        out = "a";
        break;
      case "b":
        out = "\b";
        break;
      case "t":
        out = "\t";
        break;
      case "n":
        out = "\n";
        break;
      case "v":
        out = "\v";
        break;
      case "f":
        out = "\f";
        break;
      case "r":
        out = "\r";
        break;
      case "e":
        out = "e";
        break;
      default:
        out = val;
    }
    return out;
  });
}

function addCopyButtonCallbacks() {
  for (const el of document.getElementsByClassName("copy-button")) {
    el.addEventListener("click", function () {
      navigator.clipboard.writeText(unescape_str(el.dataset.value)).then(
        function () {
          el.classList.add("success", "fa-check")
          el.classList.remove("fa-copy")
        },
        function () {
          el.classList.add("error", "fa-times")
          el.classList.remove("fa-copy")
        }
      );

      setTimeout(function () {
        el.classList.add("fa-copy")
        el.classList.remove("success", "fa-check", "fa-times")
      }, 5000);
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", addCopyButtonCallbacks);
} else {
  addCopyButtonCallbacks();
}
