"Provides a namespace for remote dependencies."
module RD
    using JSON: JSON
    using Base64
    using ....Documenter: hascurl
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
    function highlightjs!(r::RequireJS, offline_version::Bool, build_path::AbstractString, origin_path=build_path, languages = String[])
        # NOTE: the CSS themes for hightlightjs are compiled into the Documenter CSS
        # When updating this dependency, it is also necessary to update the the CSS
        # files the CSS files in assets/html/scss/highlightjs
        hljs_version = "11.8.0"
        push!(r, process_remote(RemoteLibrary(
            "highlight",
            "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/$(hljs_version)/highlight.min.js"
        ), offline_version, build_path, origin_path))
        languages = ["julia", "julia-repl", languages...]
        for language in languages
            language = jsescape(language)
            push!(r, process_remote(RemoteLibrary(
                "highlight-$(language)",
                "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/$(hljs_version)/languages/$(language).min.js",
                deps = ["highlight"]
            ), offline_version, build_path, origin_path))
        end
        push!(r, Snippet(
            vcat(["jquery", "highlight"], ["highlight-$(jsescape(language))" for language in languages]),
            ["\$"],
            raw"""
            $(document).ready(function() {
                hljs.highlightAll();
            })
            """
        ))
    end

    # MathJax & KaTeX
    const katex_version = "0.16.8"
    const katex_css = "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/katex.min.css"
    function mathengine!(r::RequireJS, engine::KaTeX, offline_version::Bool, build_path, origin_path=build_path)
        push!(r, process_remote(RemoteLibrary(
            "katex",
            "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/katex.min.js"
        ), offline_version, build_path, origin_path))
        push!(r, process_remote(RemoteLibrary(
            "katex-auto-render",
            "https://cdnjs.cloudflare.com/ajax/libs/KaTeX/$(katex_version)/contrib/auto-render.min.js",
            deps = ["katex"],
        ), offline_version, build_path, origin_path))
        push!(r, Snippet(
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
        ))
    end
    function mathengine!(r::RequireJS, engine::MathJax2, offline_version::Bool, build_path, origin_path=build_path)
        url = isempty(engine.url) ? "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.9/MathJax.js?config=TeX-AMS_HTML" : engine.url
        url = process_remote(url, offline_version, build_path, origin_path)
        push!(r, RemoteLibrary(
            "mathjax",
            url,
            exports = "MathJax"
        ))
        push!(r, Snippet(["mathjax"], ["MathJax"],
            """
            MathJax.Hub.Config($(json_jsescape(engine.config, 2)));
            """
        ))
    end
    function mathengine!(r::RequireJS, engine::MathJax3, offline_version::Bool, build_path, origin_path=build_path)
        url = isempty(engine.url) ? "https://cdnjs.cloudflare.com/ajax/libs/mathjax/3.2.2/es5/tex-svg.js" : engine.url
        url = process_remote(url, offline_version, build_path, origin_path)
        push!(r, Snippet([], [],
            """
            window.MathJax = $(json_jsescape(engine.config, 2));

            (function () {
                var script = document.createElement('script');
                script.src = '$url';
                script.async = true;
                document.head.appendChild(script);
            })();
            """
        ))
    end
    mathengine(::RequireJS, ::Nothing) = nothing

    process_remote(dep, offline_version::Bool, build_path, origin_path=build_path) = offline_version ? _process(dep, build_path, origin_path) : dep
    _process(dep::RemoteLibrary, build_path, origin_path) = RemoteLibrary(dep.name, _process(dep.url, build_path, origin_path); deps = dep.deps, exports = dep.exports)
    # hascurl() = (try; success(`curl --version`); catch err; false; end)

    function _download_file_content(url::AbstractString)
        cmd = `curl $url -s --output -`
        try
            return read(cmd, String)
        catch err
            @error "$cmd failed: ", err
            error()
            return
        end
    end

    function _process(url::AbstractString, output_path, origin_path)
        if !hascurl()
            @error "offline_version requires curl."
            error()
        end
        result = _download_file_content(url)
        filename = split(url, "/")[end]
        filepath = joinpath(output_path, filename)
        if !isfile(filepath)
            mkpath(dirname(filepath))
            open(filepath, "w") do f
                if splitext(filepath)[end] == ".css"
                    result = _process_downloaded_css(result, url, filepath)
                end
                write(f, result)
            end
        end
        
        return relpath(filepath, origin_path*"/")
    end

    function _process_downloaded_css(file_content, origin_url, origin_path)
        url_regex = r"url\(([^)]+)\)"
        replace(file_content, url_regex => s -> begin
            rel_url = match(url_regex, s).captures[1]
            url = normpath(dirname(origin_url), rel_url)
            encoded_file = Base64.base64encode(_download_file_content(url))
            return "url(data:font/truetype;charset=utf-8;base64,$(encoded_file))"
        end)
    end
end
