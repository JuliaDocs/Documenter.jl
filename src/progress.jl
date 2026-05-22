# Internal hook used at the page-iterating loops in `expand`, doctest running,
# and the HTML/LaTeX writers. Default is identity (no-op). The
# `DocumenterProgressMeterExt` package extension overrides this on
# `AbstractVector` to return a `ProgressMeter.Progress`-backed wrapping
# iterator. Activate by adding ProgressMeter to your docs project and writing
# `using ProgressMeter` in `make.jl`.
progress_iter(iter; desc::AbstractString = "") = iter
