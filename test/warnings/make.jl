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

###########################################################################################

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
┌ Warning: failed to parse code block in src/at-docs.md:19-21
│   exception =
│    ParseError:
│    # Error @ none:1:2
│    1 !in 2
│    #└────┘ ── extra tokens after end of expression
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtDocsWarningTests end

###########################################################################################

@doc raw"""
    dummyFunctionWithUnbalancedDollar()

It is possible to create pseudo-interpolations with the `Markdown` parser: $quux.

$([0 1 ; 2 3])

They do not get evaluated.
"""
function dummyFunctionWithUnbalancedDollar end

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-eval")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
┌ Warning: failed to parse code block in src/at-eval.md:13-15
│   exception =
│    ParseError:
│    # Error @ none:1:2
│    1 !in 2
│    #└────┘ ── extra tokens after end of expression
└ @ Documenter
┌ Warning: Invalid type of object in @eval in src/at-eval.md:19-21
│ ```@eval
│ "expanded_"*"eval"
│ ```
│ Evaluated to `String`, but should be one of
│  - Nothing
│  - Markdown.MD
│ Falling back to textual code block representation.
│
│ If you are seeing this warning/error after upgrading Documenter and this used to work,
│ please open an issue on the Documenter issue tracker.
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtEvalWarningTests end

###########################################################################################

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-example")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
┌ Warning: failed to parse code block in src/at-example.md:13-15
│   exception =
│    ParseError:
│    # Error @ none:1:2
│    1 !in 2
│    #└────┘ ── extra tokens after end of expression
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtExampleWarningTests end

###########################################################################################

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-meta")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtMetaWarningTests end

###########################################################################################

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-repl")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
┌ Warning: failed to parse code block in src/at-repl.md:13-15
│   exception =
│    ParseError:
│    # Error @ none:1:2
│    1 !in 2
│    #└────┘ ── extra tokens after end of expression
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtReplWarningTests end

###########################################################################################

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("at-setup")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
┌ Warning: failed to run `@setup` block in src/at-setup.md:9-11
│ ```@setup
│ 1 !in 2
│ ```
│   exception =
│    LoadError: ParseError:
│    # Error @ string:1:2
│    1 !in 2
│    #└────┘ ── extra tokens after end of expression
│    in expression starting at string:1
└ @ Documenter
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```
"""
module AtSetupWarningTests end

###########################################################################################

@doc raw"""
```jldoctest; setup=:(using ..WarningTests)
julia> WarningTests.run_warnings_test("dollar")
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
┌ Warning: Unexpected Julia interpolation in the Markdown. This probably means that you have an
│ unbalanced or un-escaped $ in the text.
│
│ To write the dollar sign, escape it with `\$`
│
│ This is in file src/dollar.md, and we were given the value:
│
│ `foo` which is of type `Symbol`
└ @ Documenter
┌ Warning: Unexpected Julia interpolation in the Markdown. This probably means that you have an
│ unbalanced or un-escaped $ in the text.
│
│ To write the dollar sign, escape it with `\$`
│
│ This is in file src/dollar.md, and we were given the value:
│
│ `[1 2 3; 4 5 6]` which is of type `Expr`
└ @ Documenter
┌ Warning: Unexpected Julia interpolation in the Markdown. This probably means that you have an
│ unbalanced or un-escaped $ in the text.
│
│ To write the dollar sign, escape it with `\$`
│
│ This is in file src/dollar.md, and we were given the value:
│
│ `quux` which is of type `Symbol`
└ @ Documenter
┌ Warning: Unexpected Julia interpolation in the Markdown. This probably means that you have an
│ unbalanced or un-escaped $ in the text.
│
│ To write the dollar sign, escape it with `\$`
│
│ This is in file src/dollar.md, and we were given the value:
│
│ `[0 1; 2 3]` which is of type `Expr`
└ @ Documenter
```
"""
module UnbalancedDollarWarningTests end

###########################################################################################

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
