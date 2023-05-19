// libraries: jquery
// arguments: $

// update the version selector with info from the siteinfo.js and ../versions.js files
$(document).ready(function() {
  let lans = DOCUMENTER_CURRENT_VERSION.split("-")
  let DOCUMENTER_CURRENT_LANGUAGE = lans.slice(-1)
  DOCUMENTER_CURRENT_VERSION = DOCUMENTER_CURRENT_VERSION.replace("-" + DOCUMENTER_CURRENT_LANGUAGE, "")

  // If the version selector is disabled with DOCUMENTER_VERSION_SELECTOR_DISABLED in the
  // siteinfo.js file, we just return immediately and not display the version selector.
  if (typeof DOCUMENTER_VERSION_SELECTOR_DISABLED === 'boolean' && DOCUMENTER_VERSION_SELECTOR_DISABLED) {
    return;
  }

  var version_selector = $("#documenter .docs-version-selector");
  var version_selector_select = $("#documenter .docs-version-selector select");
  var language_selector_select = $("#documenter .docs-language-selector select");

  let changeCallback = (x) => {
    let target_ver = version_selector_select.children("option:selected").get(0).value;
    let target_lan = language_selector_select.children("option:selected").get(0).value;
    if (target_ver.endsWith("/")){
      target_ver=target_ver.slice(0,-1)
    }
    window.location.href = target_ver + "-" + target_lan;
  }
  version_selector_select.change(changeCallback);
  language_selector_select.change(changeCallback);

  // add the current version to the selector based on siteinfo.js, but only if the selector is empty
  if (typeof DOCUMENTER_CURRENT_VERSION !== 'undefined' && $('#version-selector > option').length == 0) {
    var option = $("<option value='#' selected='selected'>" + DOCUMENTER_CURRENT_VERSION + "</option>");
    version_selector_select.append(option);
  }

  if (typeof DOC_VERSIONS !== 'undefined') {
    var existing_versions = version_selector_select.children("option");
    var existing_versions_texts = existing_versions.map(function(i,x){return x.text});
    DOC_VERSIONS.forEach(function(each) {
      var version_url = documenterBaseURL + "/../" + each + "/";
      var existing_id = $.inArray(each, existing_versions_texts);
      // if not already in the version selector, add it as a new option,
      // otherwise update the old option with the URL and enable it
      if (existing_id == -1) {
        var option = $("<option value='" + version_url + "'>" + each + "</option>");
        version_selector_select.append(option);
      } else {
        var option = existing_versions[existing_id];
        option.value = version_url;
        option.disabled = false;
      }
    });
  }

  // add to other dropdown
  console.log("here")
  console.log(language_selector_select)
  var option = $("<option value='en'>en</option>");
  language_selector_select.append(option);

  option = $("<option value='br'>br</option>");
  language_selector_select.append(option);

  option = $("<option value='es'>es</option>");

  language_selector_select.append(option);
  // only show the version selector if the selector has been populated
  if (version_selector_select.children("option").length > 0) {
    version_selector.toggleClass("visible");
  }
})
