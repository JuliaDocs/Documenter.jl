module MissingDocs
    export f

    "exported"
    f(x) = x

    "unexported"
    g(x) = x
end

using Documenter

for sym in [:none, :exports]
    makedocs(
        root = dirname(@__FILE__),
        source = joinpath("src", string(sym)),
        build = joinpath("build", string(sym)),
        modules = MissingDocs,
        checkdocs = sym,
        format = Documenter.Formats.HTML,
        sitename = "MissingDocs Checks",
    )
end
