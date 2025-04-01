using Documenter

module Foo
"bar"
function bar end
end

"Docstring"
const DocString = 1

makedocs(sitename = "!!!")

node = Sys.which("node")
wij_js = joinpath(@__DIR__, "write_index_json.js")
si_js = joinpath(@__DIR__, "build", "search_index.js")
si_json = joinpath(@__DIR__, "search_index.json")
let cmd = `$(node) $(wij_js) $(si_js) $(si_json)`
    @info "Running: $(cmd)"
    run(cmd)
end
