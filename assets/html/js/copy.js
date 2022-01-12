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
          el.innerText = "Copied";
        },
        function () {
          el.innerText = "Oops";
        }
      );

      setTimeout(function () {
        el.innerText = "Copy";
      }, 5000);
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", addCopyButtonCallbacks);
} else {
  addCopyButtonCallbacks();
}
