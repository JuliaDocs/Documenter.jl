module DocumenterProgressMeterExt

import Documenter
using ProgressMeter: Progress, next!, finish!

mutable struct ProgressIter{T}
    iter::T
    progress::Progress
    started::Bool
end

Base.length(p::ProgressIter) = length(p.iter)
Base.eltype(::Type{ProgressIter{T}}) where {T} = eltype(T)
Base.IteratorSize(::Type{<:ProgressIter}) = Base.HasLength()
Base.IteratorEltype(::Type{ProgressIter{T}}) where {T} = Base.IteratorEltype(T)

function Base.iterate(p::ProgressIter)
    result = iterate(p.iter)
    if result === nothing
        finish!(p.progress)
        return nothing
    end
    p.started = true
    return result
end

function Base.iterate(p::ProgressIter, state)
    next!(p.progress)
    result = iterate(p.iter, state)
    if result === nothing
        finish!(p.progress)
        return nothing
    end
    return result
end

function Documenter.progress_iter(iter::AbstractVector; desc::AbstractString = "")
    n = length(iter)
    bar = Progress(n; desc = desc, color = :blue)
    return ProgressIter(iter, bar, false)
end

end # module
