"Provides a namespace for remote dependencies."
module RD
using JSON: JSON
using ....Documenter.JSDependencies: RemoteLibrary, Snippet, RequireJS, jsescape, json_jsescape
using ..HTMLWriter: KaTeX, MathJax, MathJax2, MathJax3

const requirejs_cdn = "https://cdnjs.cloudflare.com/ajax/libs/require.js/2.3.6/require.min.js"
const lato = "https://cdnjs.cloudflare.com/ajax/libs/lato-font/3.0.0/css/lato-font.min.css"
const juliamono = "https://cdnjs.cloudflare.com/ajax/libs/juliamono/0.050/juliamono.min.css"
const fontawesome_version = "6.4.2"
const fontawesome_css = [
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/$(fontawesome_version)/css/fontawesome.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/$(fontawesome_version)/css/solid.min.css",
    "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/$(fontawesome_version)/css/brands.min.css",
]

const jquery = RemoteLibrary("jquery", "https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.0/jquery.min.js")
const jqueryui = RemoteLibrary("jqueryui", "https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.13.2/jquery-ui.min.js")
const lodash = RemoteLibrary("lodash", "https://cdnjs.cloudflare.com/ajax/libs/lodash.js/4.17.21/lodash.min.js")

# headroom
const headroom_version = "0.12.0"
const headroom = RemoteLibrary("headroom", "https://cdnjs.cloudflare.com/ajax/libs/headroom/$(headroom_version)/headroom.min.js")
const headroom_jquery = RemoteLibrary(
    "headroom-jquery",
    "https://cdnjs.cloudflare.com/ajax/libs/headroom/$(headroom_version)/jQuery.headroom.min.js",
    deps = ["jquery", "headroom"],
)

# highlight.js
"Add the highlight.js dependencies and snippet to a [`RequireJS`](@ref) declaration."
function highlightjs!(r::RequireJS, languages = String[])
    # NOTE: the CSS themes for hightlightjs are compiled into the Documenter CSS
    # When updating this dependency, it is also necessary to update the the CSS
    # files the CSS files in assets/html/scss/highlightjs
    hljs_version = "11.8.0"
    push!(
        r,
        RemoteLibrary(
            "highlight",
            "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/$(hljs_version)/highlight.min.js"
        )
    )
    languages = ["julia", "julia-repl", languages...]
    for language in languages
        language = jsescape(language)
        push!(
            r,
            RemoteLibrary(
                "highlight-$(language)",
                "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/$(hljs_version)/languages/$(language).min.js",
                deps = ["highlight"]
            )
        )
    end
    push!(
        r,
        Snippet(
            vcat(["jquery", "highlight"], ["highlight-$(jsescape(language))" for language in languages]),
            ["\$"],
            raw"""
            $(document).ready(function() {
                hljs.highlightAll();
            })
            """
        )
    )
    return
end

# MathJax & KaTeX
const katex_version = "0.16.8"
const katex_css = "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/katex.min.css"
function mathengine!(r::RequireJS, engine::KaTeX)
    push!(
        r,
        RemoteLibrary(
            "katex",
            "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/katex.min.js"
        )
    )
    push!(
        r,
        RemoteLibrary(
            "katex-auto-render",
            "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/contrib/auto-render.min.js",
            deps = ["katex"],
        )
    )
    push!(
        r,
        Snippet(
            ["jquery", "katex", "katex-auto-render"],
            ["\$", "katex", "renderMathInElement"],
            """
            \$(document).ready(function() {
              renderMathInElement(
                document.body,
                $(json_jsescape(engine.config, 2))
              );
            })
            """
        )
    )
    return
end
function mathengine!(r::RequireJS, engine::MathJax2)
    url = isempty(engine.url) ? "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.9/MathJax.js?config=TeX-AMS_HTML" : engine.url
    push!(
        r,
        RemoteLibrary("mathjax", url, exports = "MathJax")
    )
    push!(
        r,
        Snippet(
            ["mathjax"], ["MathJax"],
            """
            MathJax.Hub.Config($(json_jsescape(engine.config, 2)));
            """
        )
    )
    return
end
function mathengine!(r::RequireJS, engine::MathJax3)
    url = isempty(engine.url) ? "https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-svg-full.js" : engine.url
    push!(
        r,
        Snippet(
            [], [],
            """
            window.MathJax = $(json_jsescape(engine.config, 2));

            (function () {
                var script = document.createElement('script');
                script.src = '$url';
                script.async = true;
                document.head.appendChild(script);
            })();
            """
        )
    )
    return
end
mathengine(::RequireJS, ::Nothing) = nothing
end
