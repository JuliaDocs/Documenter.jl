module TextDiff

using Compat
using DocStringExtensions

# Utilities.

function lcs(old_tokens::Vector, new_tokens::Vector)
    m = length(old_tokens)
    n = length(new_tokens)
    weights = zeros(Int, m + 1, n + 1)
    for i = 2:(m + 1), j = 2:(n + 1)
        weights[i, j] = old_tokens[i - 1] == new_tokens[j - 1] ?
            weights[i - 1, j - 1] + 1 : max(weights[i, j - 1], weights[i - 1, j])
    end
    return weights
end

function makediff(weights::Matrix, old_tokens::Vector, new_tokens::Vector)
    m = length(old_tokens)
    n = length(new_tokens)
    diff = Vector{Pair{Symbol, SubString{String}}}()
    makediff!(diff, weights, old_tokens, new_tokens, m + 1, n + 1)
    return diff
end

function makediff!(out, weights, X, Y, i, j)
    if i > 1 && j > 1 && X[i - 1] == Y[j - 1]
        makediff!(out, weights, X, Y, i - 1, j - 1)
        push!(out, :normal => X[i - 1])
    else
        if j > 1 && (i == 1 || weights[i, j - 1] >= weights[i - 1, j])
            makediff!(out, weights, X, Y, i, j - 1)
            push!(out, :green => Y[j - 1])
        elseif i > 1 && (j == 1 || weights[i, j - 1] < weights[i - 1, j])
            makediff!(out, weights, X, Y, i - 1, j)
            push!(out, :red => X[i - 1])
        end
    end
    return out
end

"""
$(SIGNATURES)

Splits `text` at `regex` matches, returning an array of substrings. The parts of the string
that match the regular expression are also included at the ends of the returned strings.
"""
function splitby(reg::Regex, text::AbstractString)
    out = SubString{String}[]
    token_first = 1
    for each in eachmatch(reg, text)
        token_last = each.offset + lastindex(each.match) - 1
        push!(out, SubString(text, token_first, token_last))
        token_first = nextind(text, token_last)
    end
    laststr = SubString(text, token_first)
    isempty(laststr) || push!(out, laststr)
    return out
end

# Diff Type.

struct Lines end
struct Words end

splitter(::Type{Lines}) = r"\n"
splitter(::Type{Words}) = r"\s+"

struct Diff{T}
    old_tokens::Vector{SubString{String}}
    new_tokens::Vector{SubString{String}}
    weights::Matrix{Int}
    diff::Vector{Pair{Symbol, SubString{String}}}

    function Diff{T}(old_text::AbstractString, new_text::AbstractString) where T
        reg = splitter(T)
        old_tokens = splitby(reg, old_text)
        new_tokens = splitby(reg, new_text)
        weights = lcs(old_tokens, new_tokens)
        diff = makediff(weights, old_tokens, new_tokens)
        return new{T}(old_tokens, new_tokens, weights, diff)
    end
end

# Display.

prefix(::Diff{Lines}, s::Symbol) = s === :green ? "+ " : s === :red  ? "- " : "  "
prefix(::Diff{Words}, ::Symbol) = ""

function showdiff(io::IO, diff::Diff)
    for (color, text) in diff.diff
        printstyled(io, prefix(diff, color), text, color=color)
    end
end

function Base.show(io::IO, diff::Diff)
    printstyled(io, color=:normal) # Reset colors.
    showdiff(io, diff)
end

end
