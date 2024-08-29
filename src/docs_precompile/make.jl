using Documenter, Logging

with_logger(NullLogger()) do
    return makedocs(
        sitename = "TestPkg",
        pages = Any[
            "Home" => "index.md",
        ],
        build = mktempdir(),
        remotes = nothing,
    )
end
