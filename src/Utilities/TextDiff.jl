module TextDiff

using Compat

const Str = all(s -> isdefined(Core, s), (:String, :AbstractString)) ? String : UTF8String

# Utilities.

function lcs(old_tokens::Vector, new_tokens::Vector)
    local m = length(old_tokens)
    local n = length(new_tokens)
    local weights = zeros(Int, m + 1, n + 1)
    for i = 2:(m + 1), j = 2:(n + 1)
        weights[i, j] = old_tokens[i - 1] == new_tokens[j - 1] ?
            weights[i - 1, j - 1] + 1 : max(weights[i, j - 1], weights[i - 1, j])
    end
    return weights
end

function makediff(weights::Matrix, old_tokens::Vector, new_tokens::Vector)
    local m = length(old_tokens)
    local n = length(new_tokens)
    local diff = Vector{Pair{Symbol, SubString{Str}}}()
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

function splitby(reg::Regex, text::AbstractString)
    local out = SubString{Str}[]
    local last = 1
    for each in eachmatch(reg, text)
        push!(out, SubString(text, last, each.match.offset + each.match.endof))
        last = each.match.endof + each.offset
    end
    local laststr = SubString(text, last)
    isempty(laststr) || push!(out, laststr)
    return out
end

# Diff Type.

immutable Lines end
immutable Words end

splitter(::Type{Lines}) = r"\n"
splitter(::Type{Words}) = r"\s+"

immutable Diff{T}
    old_tokens::Vector{SubString{Str}}
    new_tokens::Vector{SubString{Str}}
    weights::Matrix{Int}
    diff::Vector{Pair{Symbol, SubString{Str}}}

    function (::Type{Diff{T}}){T}(old_text::AbstractString, new_text::AbstractString)
        local reg = splitter(T)
        local old_tokens = splitby(reg, old_text)
        local new_tokens = splitby(reg, new_text)
        local weights = lcs(old_tokens, new_tokens)
        local diff = makediff(weights, old_tokens, new_tokens)
        return new{T}(old_tokens, new_tokens, weights, diff)
    end
end

# Display.

prefix(::Diff{Lines}, s::Symbol) = s === :green ? "+ " : s === :red  ? "- " : "  "
prefix(::Diff{Words}, ::Symbol) = ""

function showdiff(io::IO, diff::Diff)
    for (color, text) in diff.diff
        print_with_color(color, io, prefix(diff, color), text)
    end
end

function Base.show(io::IO, diff::Diff)
    print_with_color(:normal, io) # Reset colors.
    showdiff(io, diff)
end

end
