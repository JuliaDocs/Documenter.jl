# Implements doctest()

"""
    doctest(package::Module; kwargs...)

Convenience method that runs and checks all the doctests for a given Julia package.
`package` must be the `Module` object corresponding to the top-level module of the package.
Behaves like an `@testset` call, returning a testset if all the doctests are successful or
throwing a `TestSetException` if there are any failures. Can be included in other testsets.

# Keywords

**`manual`** controls how manual pages are handled. By default (`manual = true`), `doctest`
assumes that manual pages are located under `docs/src`. If that is not the case, the
`manual` keyword argument can be passed to specify the directory. Setting `manual = false`
will skip doctesting of manual pages altogether.

Additional keywords are passed on to the main [`doctest`](@ref) method.
"""
function doctest(package::Module; manual = true, testset = nothing, kwargs...)
    if pathof(package) === nothing
        throw(ArgumentError("$(package) is not a top-level package module."))
    end
    source = nothing
    if manual === true
        source = normpath(joinpath(dirname(pathof(package)), "..", "docs", "src"))
        if !isdir(source)
            msg = """
            Package $(package) does not have a documentation source directory at standard location.
            Searched at: $(source)
            If the manual pages are elsewhere, pass their directory as the `manual` keyword
            argument, or `manual = false` to skip doctesting them.
            """
            throw(ArgumentError(msg))
        end
    end
    testset = (testset === nothing) ? "Doctests: $(package)" : testset
    return doctest(source, [package]; testset = testset, kwargs...)
end

"""
    doctest(source, modules; kwargs...)

Runs all the doctests in the given modules and on manual pages under the `source` directory.
Behaves like an `@testset` call, returning a testset if all the doctests are successful or
throwing a `TestSetException` if there are any failures. Can be included in other testsets.

The manual pages are searched recursively in subdirectories of `source` too. Doctesting of
manual pages can be disabled if `source` is set to `nothing`.

# Keywords

**`testset`** specifies the name of the testset (default `"Doctests"`).

**`doctestfilters`** is a vector of regexes or regex/substitution pairs to filter tests (see the manual on [Filtering Doctests](@ref))

**`fix`**, if set to `true`, updates all the doctests that fail with the correct output
(default `false`).

**`plugins`** is a list of [`Documenter.Plugin`](@ref) objects to be forwarded to
[`makedocs`](@ref). Use as directed by the documentation of a third-party plugin.

**`meta`** can be used to provide default values for the `@meta` blocks of every page, in
the same way as the `meta` keyword of [`makedocs`](@ref). For example
`meta = Dict(:DocTestSetup => :(using MyPackage))` sets `DocTestSetup` for every doctest,
complementing [`DocMeta.setdocmeta!`](@ref) which only applies to docstrings.

!!! warning
    When running `doctest(...; fix=true)`, Documenter will modify the Markdown and Julia
    source files. It is strongly recommended that you only run it on packages in Pkg's
    develop mode and commit any staged changes. You should also review all the changes made
    by `doctest` before committing them, as there may be edge cases when the automatic
    fixing fails.
"""
function doctest(
        source::Union{AbstractString, Nothing},
        modules::AbstractVector{Module};
        fix = false,
        testset = "Doctests",
        doctestfilters = Regex[],
        plugins = Plugin[],
        meta::Dict{Symbol} = Dict{Symbol, Any}(),
    )
    function all_doctests()
        dir = mktempdir()
        try
            @debug "Doctesting in temporary directory: $(dir)" modules
            if source === nothing
                source = joinpath(dir, "src")
                mkdir(source)
            end
            makedocs(;
                root = dir,
                source = source,
                sitename = "",
                doctest = fix ? :fix : :only,
                modules = modules,
                doctestfilters = doctestfilters,
                # When doctesting, we don't really want to get bogged down with issues
                # related to determining the remote repositories for edit URLs and such
                remotes = nothing,
                plugins = plugins,
                meta = meta,
            )
            return true
        catch err
            @error "Doctesting failed" exception = (err, catch_backtrace())
            return false
        finally
            try
                rm(dir; recursive = true)
            catch e
                @warn "Documenter was unable to clean up the temporary directory $(dir)" exception = e
            end
        end
    end
    return @testset "$testset" begin
        @test all_doctests()
    end
end
