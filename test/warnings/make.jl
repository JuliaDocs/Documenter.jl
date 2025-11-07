module WarningTests

# Test warnings
# see https://github.com/JuliaDocs/Documenter.jl/issues/2805

using Test
using Documenter
using IOCapture

isdefined(Main, :Documenter) || @eval Main import Documenter

function run_warnings_test(name::String)
    captured = IOCapture.capture() do
        makedocs(;
            sitename = name,
            pages = ["index.md", "$name.md"],
            pagesonly = true,
            warnonly = true,
            format = Documenter.HTML(
                prettyurls = false,
                inventory_version = "",
            ),
        )
    end
    @assert isnothing(captured.value)

    # sanitize the output
    output = captured.output
    output = replace(output, r"\@ Documenter.*" => "@ Documenter")
    output = replace(output, "src\\" => "src/")
    return print(output)
end

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-docs")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
┌ Warning: undefined binding 'Base.nonsenseBindingThatDoesNotExist' in `@docs` block in src/at-docs.md:4-6
│ ```@docs
│ Base.nonsenseBindingThatDoesNotExist()
│ ```
└ @ Documenter
┌ Warning: no docs found for 'Base.sin()' in `@docs` block in src/at-docs.md:9-11
│ ```@docs
│ Base.sin()
│ ```
└ @ Documenter
┌ Warning: failed to evaluate `Base.sin(::NonsenseTypeThatDoesNotExist)` in `@docs` block in src/at-docs.md:14-16
│ ```@docs
│ Base.sin(::NonsenseTypeThatDoesNotExist)
│ ```
│   exception =
│    UndefVarError: `NonsenseTypeThatDoesNotExist` not defined in `Main`
│    Suggestion: check for spelling errors or missing imports.
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtDocsWarningTests end

fixtests = haskey(ENV, "DOCUMENTER_FIXTESTS")

# run the doctests in Julia >= 1.10 (some outputs have minor difference in
# older Julia versions, and it just doesn't seem worth the trouble of coping
# with that "properly")
VERSION >= v"1.10" && makedocs(;
    sitename = "",
    doctest = fixtests ? :fix : :only,
    modules = [WarningTests],
    remotes = nothing,
)

end
