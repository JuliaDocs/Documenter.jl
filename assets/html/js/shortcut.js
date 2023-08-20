// libraries: jquery
// arguments: $

let search_modal_header = `
  <header class="modal-card-head gap-2 is-align-items-center is-justify-content-space-between w-100 px-3">
    <div class="field mb-0 w-100">
      <p class="control has-icons-right">
        <input class="input documenter-search-input" type="text" placeholder="Search" />
        <span class="icon is-small is-right has-text-primary-dark">
          <i class="fas fa-magnifying-glass"></i>
        </span>
      </p>
    </div>
    <div class="icon is-size-4 is-clickable close-search-modal">
      <i class="fas fa-times"></i>
    </div>
  </header>
`;

let initial_search_body = `
  <div class="has-text-centered my-5 py-5">Type something to get started!</div>
`;

let search_modal_footer = `
  <footer class="modal-card-foot">
    <span>
      <kbd class="search-modal-key-hints">Ctrl</kbd> +
      <kbd class="search-modal-key-hints">/</kbd> to search
    </span>
    <span class="ml-3"> <kbd class="search-modal-key-hints">esc</kbd> to close </span>
  </footer>
`;

$(document.body).append(
  `
    <div class="modal" id="search-modal">
      <div class="modal-background"></div>
      <div class="modal-card search-min-width-50 search-min-height-100 is-justify-content-center">
        ${search_modal_header}
        <section class="modal-card-body is-flex is-flex-direction-column is-justify-content-center gap-4 search-modal-card-body">
          ${initial_search_body}
        </section>
        ${search_modal_footer}
      </div>
    </div>
  `
);

document.querySelector(".docs-search-query").addEventListener("click", () => {
  openModal();
});

document.querySelector(".close-search-modal").addEventListener("click", () => {
  closeModal();
});

document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key === "/") {
    openModal();
  } else if (event.key === "Escape") {
    closeModal();
  }

  return false;
});

// Functions to open and close a modal
function openModal() {
  let searchModal = document.querySelector("#search-modal");

  searchModal.classList.add("is-active");
  document.querySelector(".documenter-search-input").focus();
}

function closeModal() {
  let searchModal = document.querySelector("#search-modal");
  let initial_search_body = `
    <div class="has-text-centered my-5 py-5">No recent searches!</div>
  `;

  searchModal.classList.remove("is-active");
  document.querySelector(".documenter-search-input").blur();

  $(".documenter-search-input").val("");
  $(".search-modal-card-body").html(initial_search_body);
}

document
  .querySelector("#search-modal .modal-background")
  .addEventListener("click", () => {
    closeModal();
  });
