"""
Provides a consistent interface to retreiving `DocStr` objects from the Julia
docsystem in both `0.4` and `0.5`.
"""
module DocSystem

using DocStringExtensions
import Markdown
import Base.Docs: MultiDoc, formatdoc, DocStr

## Bindings ##

"""
Converts an object to a `Base.Docs.Binding` object.

$(SIGNATURES)

Supported inputs are:

- `Binding`
- `DataType`
- `Function`
- `Module`
- `Symbol`

Note that unsupported objects will throw an `ArgumentError`.
"""
binding(any::Any) = throw(ArgumentError("cannot convert `$(repr(any))` to a `Binding`."))

#
# The simple definitions.
#
binding(b::Docs.Binding) = binding(b.mod, b.var)
binding(d::DataType)     = binding(d.name.module, d.name.name)
binding(m::Module)       = binding(m, nameof(m))
binding(s::Symbol)       = binding(Main, s)
binding(f::Function)     = binding(typeof(f).name.module, typeof(f).name.mt.name)

#
# We need a lookup table for `IntrinsicFunction`s since they do not track their
# own name and defining module.
#
# Note that `IntrinsicFunction` is exported from `Base` in `0.4`, but not in `0.5`.
#
let INTRINSICS = Dict(map(s -> getfield(Core.Intrinsics, s) => s, names(Core.Intrinsics, all=true)))
    global binding(i::Core.IntrinsicFunction) = binding(Core.Intrinsics, INTRINSICS[i]::Symbol)
end

#
# Normalise the parent module.
#
# This is done within the `Binding` constructor on `0.5`, but not on `0.4`.
#
function binding(m::Module, v::Symbol)
    m = nameof(m) === v ? parentmodule(m) : m
    Docs.Binding(m, v)
end

#
# Pseudo-eval of `Expr`s to find their equivalent `Binding`.
#
binding(m::Module, x::Expr) =
    Meta.isexpr(x, :.) ? binding(getmod(m, x.args[1]), x.args[2].value) :
    Meta.isexpr(x, [:call, :macrocall, :curly]) ? binding(m, x.args[1]) :
    Meta.isexpr(x, :where) ? binding(m, x.args[1].args[1]) :
        error("`binding` cannot understand expression `$x`.")

# Helper methods for the above `binding` method.
getmod(m::Module, x::Expr) = getfield(getmod(m, x.args[1]), x.args[2].value)
getmod(m::Module, s::Symbol) = getfield(m, s)

binding(m::Module, q::QuoteNode) = binding(Main, q.value)

binding(m::Module, λ::Any) = binding(λ)

## Signatures. ##

function signature(x, str::AbstractString)
    ts = Base.Docs.signature(x)
    (Meta.isexpr(x, :macrocall, 2) && !endswith(strip(str), "()")) ? :(Union{}) : ts
end

## Docstring containers. ##


"""
Construct a `MultiDoc` object from the provided argument.

Valid inputs are:

- `Markdown.MD`
- `Docs.FuncDoc`
- `Docs.TypeDoc`

"""
function multidoc end

function multidoc(markdown::Markdown.MD)
    md = MultiDoc()
    sig = Union{}
    push!(md.order, sig)
    md.docs[sig] = docstr(markdown)
    md
end



"""
$(SIGNATURES)

Construct a `DocStr` object from a `Markdown.MD` object.

The optional keyword arguments are used to add new data to the `DocStr`'s
`.data` dictionary.
"""
function docstr(md::Markdown.MD; kws...)
    data = Dict{Symbol, Any}(
        :path => md.meta[:path],
        :module => md.meta[:module],
        :linenumber => 0,
    )
    doc = DocStr(Core.svec(), md, data)
    for (key, value) in kws
        doc.data[key] = value
    end
    doc
end
docstr(other) = other


## Formatting `DocStr`s. ##




## Converting docstring caches. ##

"""
$(SIGNATURES)

Converts a `0.4`-style docstring cache into a `0.5` one.

The original docstring cache is not modified.
"""
function convertmeta(meta::IdDict{Any,Any})
    if !haskey(CACHED, meta)
        docs = IdDict{Any,Any}()
        for (k, v) in meta
            if !isa(k, Union{Number, AbstractString, IdDict{Any,Any}})
                docs[binding(k)] = multidoc(v)
            end
        end
        CACHED[meta] = docs
    end
    CACHED[meta]::IdDict{Any,Any}
end
const CACHED = IdDict{Any,Any}()


## Get docs from modules.

"""
$(SIGNATURES)

Find all `DocStr` objects that match the provided arguments exactly.
- `binding`: the name of the object.
- `typesig`: the signature of the object. Default: `Union{}`.
- `compare`: how to compare signatures? (`==` (default), `<:` or `>:`)
- `modules`: which modules to search through. Default: *all modules*.

Return a `Vector{DocStr}` ordered by definition order.
"""
function getspecificdocs(
        binding::Docs.Binding,
        typesig::Type = Union{},
        compare = (==),
        modules = Docs.modules,
    )
    # Fall back to searching all modules if user provides no modules.
    modules = isempty(modules) ? Docs.modules : modules
    # Keywords are special-cased within the docsystem. Handle those first.
    iskeyword(binding) && return [docstr(Base.Docs.keywords[binding.var])]
    # Handle all the other possible bindings.
    results = DocStr[]
    for mod in modules
        meta = getmeta(mod)
        if haskey(meta, binding)
            multidoc = meta[binding]::MultiDoc
            for signature in multidoc.order
                if compare(typesig, signature)
                    doc = multidoc.docs[signature]
                    doc.data[:binding] = binding
                    doc.data[:typesig] = signature
                    push!(results, doc)
                end
            end
        end
    end
    results
end

"""
$(SIGNATURES)

Find all `DocStr` objects that somehow match the provided arguments.
That is, if [`getspecificdocs`](@ref) fails, get docs for aliases of
`binding` (unless `aliases` is set to `false). For `compare` being `==` also
try getting docs for `<:`.
"""
function getdocs(
        binding::Docs.Binding,
        typesig::Type = Union{};
        compare = (==),
        modules = Docs.modules,
        aliases = true,
    )
    results = getspecificdocs(binding, typesig, compare, modules)
    if isempty(results) && compare == (==)
        results = getspecificdocs(binding, typesig, (<:), modules)
    end
    if isempty(results) && aliases && (b = aliasof(binding)) != binding
        results = getspecificdocs(b, typesig, compare, modules)
        if isempty(results) && compare == (==)
            results = getspecificdocs(b, typesig, (<:), modules)
        end
    end
    results
end

"""
$(SIGNATURES)

Accepts objects of any type and tries to convert them to `Binding`s before
searching for the `Binding` in the docsystem.

Note that when conversion fails this method returns an empty `Vector{DocStr}`.
"""
function getdocs(object::Any, typesig::Type = Union{}; kws...)
    binding = aliasof(object, object)
    binding === object ? DocStr[] : getdocs(binding, typesig; kws...)
end

#
# Helper methods used by the `getdocs` function above.
#

getmeta(m::Module) = Docs.meta(m)

import Base.Docs: aliasof, resolve, defined


aliasof(s::Symbol, b) = binding(s)

iskeyword(b::Docs.Binding) = b.mod === Main && haskey(Base.Docs.keywords, b.var)
ismacro(b::Docs.Binding) = startswith(string(b.var), '@')


function category(b::Docs.Binding)
    if iskeyword(b)
        :keyword
    elseif ismacro(b)
        :macro
    else
        category(resolve(b))
    end
end
category(::Function) = :function
category(::DataType) = :type
category(x::UnionAll) = category(Base.unwrap_unionall(x))
category(::Module) = :module
category(::Any) = :constant

"""
    DocSystem.parsedoc(docstr::DocStr)

Thin internal wrapper around `Base.Docs.parsedoc` which prints additional debug information
in case `Base.Docs.parsedoc` fails with an exception.
"""
function parsedoc(docstr::DocStr)
    try
        Base.Docs.parsedoc(docstr)
    catch exception
        @error """
        parsedoc failed to parse a docstring into Markdown. This indicates a problem with the docstring.
        """ exception docstr.data collect(docstr.text) docstr.object
        # Note: collect is there because svec does not print as nicely as a vector
        rethrow(exception)
    end
end

end
