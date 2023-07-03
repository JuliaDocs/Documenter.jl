using Documenter

makedocs(
    debug = true,
    doctestfilters = [r"Ptr{0x[0-9]+}"],
    sitename = "Documenter example",
    pages = ["index.md"],
    remotes = nothing,
)
