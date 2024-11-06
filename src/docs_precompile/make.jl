using Documenter, Logging

with_logger(NullLogger()) do
    makedocs(
        sitename = "TestPkg",
        pages = Any[
            "Home" => "index.md",
        ],
        build = mktempdir(),
        remotes = nothing,
    )
end
