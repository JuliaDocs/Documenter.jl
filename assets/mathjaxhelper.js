MathJax.Hub.Config({
  "tex2jax": {
    inlineMath: [['$','$'], ['\\(','\\)']],
    processEscapes: true
  }
});
MathJax.Hub.Config({
  config: ["MMLorHTML.js"],
  jax: ["input/TeX", "output/HTML-CSS", "output/NativeMML"],
  extensions: ["MathMenu.js", "MathZoom.js", "AMSmath.js", "AMSsymbols.js", "autobold.js", "autoload-all.js"]
});
MathJax.Hub.Config({
  TeX: { equationNumbers: { autoNumber: "AMS" } }
});
