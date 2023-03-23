// libraries: jquery
// arguments: $

function set_theme(theme) {
  var active = null;
  var disabled = [];
  for (var i = 0; i < document.styleSheets.length; i++) {
    var ss = document.styleSheets[i];
    var themename = ss.ownerNode.getAttribute("data-theme-name");
    if(themename === null) continue; // ignore non-theme stylesheets
    // Find the active theme
    if(themename === theme) active = ss;
    else disabled.push(ss);
  }
  if(active !== null) {
    active.disabled = false;
    if(active.ownerNode.getAttribute("data-theme-primary") === null) {
      document.getElementsByTagName('html')[0].className = "theme--" + theme;
    } else {
      document.getElementsByTagName('html')[0].className = "";
    }
    disabled.forEach(function(ss){
      ss.disabled = true;
    });
  }

  // Store the theme in localStorage
  if(typeof(window.localStorage) !== "undefined") {
    window.localStorage.setItem("documenter-theme", theme);
  } else {
    console.error("Browser does not support window.localStorage");
  }
}

// Theme picker setup
$(document).ready(function() {
  // onchange callback
  $('#documenter-themepicker').change(function themepick_callback(ev){
    var themename = $('#documenter-themepicker option:selected').attr('value');
    if (themename === 'auto') {
      window.localStorage.removeItem("documenter-theme");
    } else {
      set_theme(themename);
    }
  });

  // Make sure that the themepicker displays the correct theme when the theme is retrieved
  // from localStorage
  if(typeof(window.localStorage) !== "undefined") {
    var theme =  window.localStorage.getItem("documenter-theme");
    if(theme !== null) {
      $('#documenter-themepicker option').each(function(i,e) {
        e.selected = (e.value === theme);
      })
    } else {
      $('#documenter-themepicker option').each(function(i,e) {
        if ($("html").hasClass(`theme--${e.value}`)) {
          e.selected = true;
        } else if (e.value === 'auto') {
          e.selected = true;
        }
      })
    }
  }
})
