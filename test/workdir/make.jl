using Documenter

const pages = [
    "Home" => "index.md",
    "File" => "file.md",
    "Subdir" => "subdir/index.md",
    "Subfile" => "subdir/file.md",
]

@info "Building builds/default"
makedocs(sitename="Test", pages = pages, build="builds/default", strict = false)

@info "Building builds/absolute"
mkdir(joinpath(@__DIR__, "builds/absolute-workdir"))
makedocs(sitename="Test", pages = pages, build="builds/absolute", workdir=joinpath(@__DIR__, "builds/absolute-workdir"), strict = false)

@info "Building builds/relative"
mkdir(joinpath(@__DIR__, "builds/relative-workdir"))
makedocs(sitename="Test", pages = pages, build="builds/relative", workdir="builds/relative-workdir", strict = false)
