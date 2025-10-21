///////////////////////////////////
function openTarget() {
  const hash = decodeURIComponent(location.hash.substring(1));
  if (hash) {
    const target = document.getElementById(hash);
    if (target) {
      const details = target.closest("details");
      if (details) details.open = true;
    }
  }
}
openTarget(); // onload
window.addEventListener("hashchange", openTarget);
window.addEventListener("load", openTarget);
