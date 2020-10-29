// Small function to quickly swap out themes. Gets put into the <head> tag..
function set_theme_from_local_storage() {
  // Browser does not support Web Storage, bail early.
  if(typeof(window.localStorage) === "undefined") return;
  // Get the user-picked theme from localStorage. May be `null`, which means the default
  // theme.
  var theme =  window.localStorage.getItem("documenter-theme");
  // Check if the browser supports user color preference
  var darkPreference = false;
  if(window.matchMedia('(prefers-color-scheme: dark)').media !== 'not all') {
    // Check if the users preference is for dark color scheme
    if(window.matchMedia('(prefers-color-scheme: dark)').matches === true) {
      darkPreference = true;
    }
  }
  // Initialize a few variables for the loop:
  //
  //  - active: will contain the index of the theme that should be active. Note that there
  //    is no guarantee that localStorage contains sane values. If `active` stays `null`
  //    we either could not find the theme or it is the default (primary) theme anyway.
  //    Either way, we then need to stick to the primary theme.
  //
  //  - disabled: style sheets that should be disabled (i.e. all the theme style sheets
  //    that are not the currently active theme)
  var active = null; var disabled = []; var darkTheme = null;
  for (var i = 0; i < document.styleSheets.length; i++) {
    var ss = document.styleSheets[i];
    // The <link> tag of each style sheet is expected to have a data-theme-name attribute
    // which must contain the name of the theme. The names in localStorage much match this.
    var themename = ss.ownerNode.getAttribute("data-theme-name");
    // attribute not set => non-theme stylesheet => ignore
    if(themename === null) continue;
    // To distinguish the default (primary) theme, it needs to have the data-theme-primary
    // attribute set.
    var isprimary = (ss.ownerNode.getAttribute("data-theme-primary") !== null);
    // If the ss is not primary then use it if the user's preference is towards dark colors
    if(!isprimary) darkTheme = themename;
    // If we find a matching theme (and it's not the default), we'll set active to non-null
    if(themename === theme) active = i;
    // Store the style sheets of inactive themes so that we could disable them
    if(themename !== theme) disabled.push(ss);
  }
  if(active !== null) {
    // If we did find an active theme, we'll (1) add the theme--$(theme) class to <html>
    document.getElementsByTagName('html')[0].className = "theme--" + theme;
    // and (2) disable all the other theme stylesheets
    disabled.forEach(function(ss){
      ss.disabled = true;
    });
  }
  else if(darkTheme !== null) {
    // If we did find an active theme, we'll (1) add the theme--$(theme) class to <html>
    document.getElementsByTagName('html')[0].className = "theme--" + darkTheme;
    // and (2) disable all the other theme stylesheets
    disabled.forEach(function(ss){
      if (ss.ownerNode.getAttribute("data-theme-name") !== darkTheme) {
        ss.disabled = true;
      }
    });
    // Store the theme in localStorage
    if(typeof(window.localStorage) !== "undefined") {
      window.localStorage.setItem("documenter-theme", darkTheme);
    } else {
      console.error("Browser does not support window.localStorage");
    }
  }
}
set_theme_from_local_storage();
