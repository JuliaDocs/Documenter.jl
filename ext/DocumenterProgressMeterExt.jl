module DocumenterProgressMeterExt

import Documenter
using ProgressMeter: Progress, next!, finish!

struct ProgressIter{T}
    iter::T
    progress::Progress
end

Base.length(p::ProgressIter) = length(p.iter)
Base.size(p::ProgressIter, dim...) = size(p.iter, dim...)
Base.axes(p::ProgressIter, dim...) = axes(p.iter, dim...)
Base.eltype(::Type{ProgressIter{T}}) where {T} = eltype(T)
Base.IteratorSize(::Type{ProgressIter{T}}) where {T} = Base.IteratorSize(T)
Base.IteratorEltype(::Type{ProgressIter{T}}) where {T} = Base.IteratorEltype(T)

function Base.iterate(p::ProgressIter, state...)
    result = iterate(p.iter, state...)
    if result === nothing
        finish!(p.progress)
    elseif !isempty(state)
        next!(p.progress)
    end
    return result
end

function Documenter.progress_iter(iter::AbstractVector)
    return ProgressIter(iter, Progress(length(iter); desc = "", color = :blue))
end

end # module
