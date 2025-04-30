"""
This module provides APIs for handling documentation metadata in modules.

The implementation is similar to how docstrings are handled in `Base` by the `Base.Docs`
module — a special variable is created in each module that has documentation metadata.

# Public API

* [`DocMeta.getdocmeta`](@ref)
* [`DocMeta.setdocmeta!`](@ref)

# Supported metadata

* `DocTestSetup`: contains the doctest setup code for doctests in the module.
* `DocTestTeardown`: contains the doctest teardown code for doctests in the module.
"""
module DocMeta
import ..Documenter
import Base: invokelatest

"The unique `Symbol` that is used to store the metadata dictionary in each module."
const META = gensym(:docmeta)

"List of modules that have the metadata dictionary added."
const METAMODULES = Module[]

"Type of the metadata dictionary."
const METATYPE = Dict{Symbol, Any}

"Dictionary of all valid metadata keys and their types."
const VALIDMETA = Dict{Symbol, Type}(
    :DocTestSetup => Union{Expr, Symbol},
    :DocTestTeardown => Union{Expr, Symbol}
)

"""
"""
function initdocmeta!(m::Module)
    if !invokelatest(isdefined, m, META)
        @debug "Creating documentation metadata dictionary (META=$META) in $m"
        Core.eval(m, :(const $META = $(METATYPE())))
        push!(METAMODULES, m)
    else
        @warn "Existing documentation metadata dictionary (META=$META) in $m. Ignoring."
    end
    return invokelatest(getfield, m, META)
end

"""
    getdocmeta(m::Module)

Returns the documentation metadata dictionary for the module `m`. The dictionary should be
considered immutable and assigning values to it is not well-defined. To set documentation
metadata values, [`DocMeta.setdocmeta!`](@ref) should be used instead.
"""
getdocmeta(m::Module) = invokelatest(isdefined, m, META) ? invokelatest(getfield, m, META) : METATYPE()

"""
    getdocmeta(m::Module, key::Symbol, default=nothing)

Return the `key` entry from the documentation metadata for module `m`, or `default` if the
value is unset.
"""
getdocmeta(m::Module, key::Symbol, default = nothing) = get(getdocmeta(m), key, default)

"""
    setdocmeta!(m::Module, key::Symbol, value; recursive=false, warn=true)

Set the documentation metadata value `key` for module `m` to `value`.

If `recursive` is set to `true`, it sets the same metadata value for all the submodules too.
If `warn` is `true`, it prints a warning when `key` already exists and it gets rewritten.
"""
function setdocmeta!(m::Module, key::Symbol, value; warn = true, recursive = false)
    key in keys(VALIDMETA) || throw(ArgumentError("Invalid metadata key\nValid keys are: $(join(keys(VALIDMETA), ", "))"))
    isa(value, VALIDMETA[key]) || throw(ArgumentError("Bad value type ($(typeof(value))) for metadata key $(key). Must be <: $(VALIDMETA[key])"))
    if recursive
        for mod in Documenter.submodules(m)
            setdocmeta!(mod, key, value; warn = warn, recursive = false)
        end
    else
        invokelatest(isdefined, m, META) || initdocmeta!(m)
        meta = getdocmeta(m)
        if warn && haskey(meta, key)
            @warn "$(key) already set for module $m. Overwriting."
        end
        meta[key] = value
    end
    return nothing
end

end
