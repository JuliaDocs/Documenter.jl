"""
Provides a consistent interface to retreiving `DocStr` objects from the Julia
docsystem in both `0.4` and `0.5`.
"""
module DocSystem

using Compat, DocStringExtensions

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
binding(any::Any) = throw(ArgumentError("cannot convert `$any` to a `Binding`."))

#
# The simple definitions.
#
binding(b::Docs.Binding) = binding(b.mod, b.var)
binding(d::DataType)     = binding(d.name.module, d.name.name)
binding(m::Module)       = binding(m, module_name(m))
binding(s::Symbol)       = binding(current_module(), s)

#
# In `0.4` some functions aren't generic, hence the `isgeneric` check here.
# We punt on using `current_module` in when not generic, which may cause
# trouble when calling this function with a qualified name.
#
binding(f::Function) = binding(typeof(f).name.module, typeof(f).name.mt.name)

#
# We need a lookup table for `IntrinsicFunction`s since they do not track their
# own name and defining module.
#
# Note that `IntrinsicFunction` is exported from `Base` in `0.4`, but not in `0.5`.
#
let INTRINSICS = Dict(map(s -> getfield(Core.Intrinsics, s) => s, names(Core.Intrinsics, true)))
    binding(i::Core.IntrinsicFunction) = binding(Core.Intrinsics, INTRINSICS[i]::Symbol)
end

#
# Normalise the parent module.
#
# This is done within the `Binding` constructor on `0.5`, but not on `0.4`.
#
function binding(m::Module, v::Symbol)
    m = module_name(m) === v ? module_parent(m) : m
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
    (Meta.isexpr(x, :macrocall, 1 + Compat.macros_have_sourceloc) && !endswith(strip(str), "()")) ? :(Union{}) : ts
end

## Docstring containers. ##

#
# `MultiDoc` objects contain a collection of related `DocStr` objects.
#
# Here "related" means that they share the same `Binding` and defining module.
#
if isdefined(Base.Docs, :MultiDoc)
    import Base.Docs: MultiDoc
else
    struct MultiDoc
        order :: Vector{Type}
        docs  :: ObjectIdDict
    end
    MultiDoc() = MultiDoc([], ObjectIdDict())
end

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

if isdefined(Base.Docs, :FuncDoc)
    function multidoc(funcdoc::Docs.FuncDoc)
        md = MultiDoc()
        append!(md.order, funcdoc.order)
        for (k, v) in funcdoc.meta
            md.docs[k] = docstr(v; source = funcdoc.source[k])
        end
        md
    end
end

if isdefined(Base.Docs, :TypeDoc)
    function multidoc(typedoc::Docs.TypeDoc)
        md = MultiDoc()
        append!(md.order, typedoc.order)
        if typedoc.main !== nothing
            unshift!(md.order, Union{})
            md.docs[Union{}] = docstr(typedoc.main; fields = typedoc.fields)
        end
        for (k, v) in typedoc.meta
            md.docs[k] = docstr(v)
        end
        md
    end
end

#
# `DocStr` objects store a raw documentation string and it's parsed form,
# which is typically a `Markdown.MD` object.
#
# Additionally arbitrary metadata in the form of `Symbol => Any` pairs may be
# stored in the `.data` `Dict`.
#
# The following data are stored in `.data`:
#
# - `:module`     Valid in both `0.4` and `0.5`.
# - `:path`       Invalid for `Base` docstrings in `0.4`.
# - `:linenumber` Invalid for docstrings in `0.4`.
# - `:binding`    Non-standard: Added by `DocSystem.getdocs`.
# - `:typesig`    Non-standard: Added by `DocSystem.getdocs`.
#
if isdefined(Base.Docs, :DocStr)
    import Base.Docs: DocStr
else
    mutable struct DocStr
        text   :: SimpleVector
        object :: Nullable
        data   :: Dict{Symbol, Any}
    end
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
    doc = DocStr(Core.svec(), Nullable(md), data)
    for (key, value) in kws
        doc.data[key] = value
    end
    doc
end
docstr(other) = other


## Formatting `DocStr`s. ##

#
# The `parsedoc` function returns the parsed object stored in a docstring.
#
# In `0.4` `parsedoc` will just return `get(d.object)` immediately since
# `d.object` is never null, and so `formatdoc` will never be called. We
# define it anyway for the sake of consistency with `0.5`.
#
if isdefined(Base.Docs, :parsedoc)
    import Base.Docs: parsedoc, formatdoc
else
    # `DocStr` should be defined by this point, whether it is from this
    # module or from `Base.Docs` and so doesn't need to be qualified.

    function formatdoc(d::DocStr)
        buffer = IOBuffer()
        for part in d.text
            formatdoc(buffer, d, part)
        end
        Markdown.parse(seekstart(buffer))
    end
    @noinline formatdoc(buffer, d, part) = print(buffer, part)

    function parsedoc(d::DocStr)
        if isnull(d.object)
            md = formatdoc(d)
            md.meta[:module] = d.data[:module]
            md.meta[:path]   = d.data[:path]
            d.object = Nullable(md)
        end
        get(d.object)
    end
end


## Converting docstring caches. ##

"""
$(SIGNATURES)

Converts a `0.4`-style docstring cache into a `0.5` one.

The original docstring cache is not modified.
"""
function convertmeta(meta::ObjectIdDict)
    if !haskey(CACHED, meta)
        docs = ObjectIdDict()
        for (k, v) in meta
            if !isa(k, Union{Number, AbstractString, ObjectIdDict})
                docs[binding(k)] = multidoc(v)
            end
        end
        CACHED[meta] = docs
    end
    CACHED[meta]::ObjectIdDict
end
const CACHED = ObjectIdDict()


## Get docs from modules.

"""
$(SIGNATURES)

Find all `DocStr` objects that match the provided arguments:

- `binding`: the name of the object.
- `typesig`: the signature of the object. Default: `Union{}`.
- `compare`: how to compare signatures? Exact (`==`) or subtypes (`<:`). Default: `<:`.
- `modules`: which modules to search through. Default: *all modules*.
- `aliases`: check aliases of `binding` when nothing is found. Default: `true`.

Returns a `Vector{DocStr}` ordered by definition order in `0.5` and by
`type_morespecific` in `0.4`.
"""
function getdocs(
        binding::Docs.Binding,
        typesig::Type = Union{};
        compare = (==),
        modules = Docs.modules,
        aliases = true,
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
    if compare == (==)
        # Exact matching of signatures:
        #
        # When we get a single match from using `==` as the comparision then we just return
        # that one result.
        #
        # Otherwise we fallback to comparing signatures using `<:` to match, hopefully, a
        # wider range of possible docstrings.
        if length(results) == 1
            results
        else
            getdocs(binding, typesig; compare = (<:), modules = modules, aliases = aliases)
        end
    else
        # When nothing is found we check whether the `binding` is an alias of some other
        # `Binding`. If so then we redo the search using that `Binding` instead.
        if aliases && isempty(results) && (b = aliasof(binding)) != binding
            getdocs(b, typesig; compare = compare, modules = modules)
        else
            results
        end
    end
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

if isdefined(Base.Docs, :META′) # The ′ character here is `\prime` not `ctranspose`.
    getmeta(m::Module) = isdefined(m, Docs.META′) ? convertmeta(Docs.meta(m)) : ObjectIdDict()
else
    getmeta(m::Module) = Docs.meta(m)
end

if isdefined(Base.Docs, :aliasof)
    import Base.Docs: aliasof, resolve, defined
else
    defined(b::Docs.Binding) = isdefined(b.mod, b.var)
    resolve(b::Docs.Binding) = getfield(b.mod, b.var)

    aliasof(t::Union{DataType, Core.IntrinsicFunction, Function, Module}, ::Any) = binding(t)
    aliasof(b::Docs.Binding) = defined(b) ? (a = aliasof(resolve(b), b); defined(a) ? a : b) : b
    aliasof(other, b) = b
end

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
if isdefined(Base, :UnionAll)
    category(x::UnionAll) = category(Base.unwrap_unionall(x))
end
category(::Module) = :module
category(::Any) = :constant

end
