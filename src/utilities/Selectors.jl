"""
An extensible code selection interface.

The `Selectors` module provides an extensible way to write code that has to dispatch on
different predicates without hardcoding the control flow into a single chain of `if`
statements.

In the following example a selector for a simple condition is implemented and the generated
selector code is described:

```julia
abstract type MySelector <: Selectors.AbstractSelector end

# The different cases we want to test.
abstract type One    <: MySelector end
abstract type NotOne <: MySelector end

# The order in which to test the cases.
Selectors.order(::Type{One})    = 0.0
Selectors.order(::Type{NotOne}) = 1.0

# The predicate to test against.
Selectors.matcher(::Type{One}, x)    = x === 1
Selectors.matcher(::Type{NotOne}, x) = x !== 1

# What to do when a test is successful.
Selectors.runner(::Type{One}, x)    = println("found one")
Selectors.runner(::Type{NotOne}, x) = println("not found")

# Test our selector with some numbers.
for i in 0:5
    Selectors.dispatch(MySelector, i)
end
```

`Selectors.dispatch(Selector, i)` will behave equivalent to the following:

```julia
function dispatch(::Type{MySelector}, i::Int)
    if matcher(One, i)
        runner(One, i)
    elseif matcher(NotOne, i)
        runner(NotOne, i)
    end
end
```

and further to

```julia
function dispatch(::Type{MySelector}, i::Int)
    if i === 1
        println("found one")
    elseif i !== 1
        println("not found")
    end
end
```

The module provides the following interface for creating selectors:

- [`order`](@ref)
- [`matcher`](@ref)
- [`runner`](@ref)
- [`strict`](@ref)
- [`disable`](@ref)
- [`dispatch`](@ref)

"""
module Selectors

import InteractiveUtils: subtypes

"""
Root selector type. Each user-defined selector must subtype from this, i.e.

```julia
abstract type MySelector <: Selectors.AbstractSelector end

abstract type First  <: MySelector end
abstract type Second <: MySelector end
```
"""
abstract type AbstractSelector end

"""
Define the precedence of each case in a selector, i.e.

```julia
Selectors.order(::Type{First})  = 1.0
Selectors.order(::Type{Second}) = 2.0
```

Note that the return type must be `Float64`. Defining multiple case types to have the same
order will result in undefined behaviour.
"""
function order end

"""
Define the matching test for each case in a selector, i.e.

```julia
Selectors.matcher(::Type{First}, x)  = x == 1
Selectors.matcher(::Type{Second}, x) = true
```

Note that the return type must be `Bool`.

To match against multiple cases use the [`Selectors.strict`](@ref) function.
"""
function matcher end

"""
Define the code that will run when a particular [`Selectors.matcher`](@ref) test returns
`true`, i.e.

```julia
Selectors.runner(::Type{First}, x)  = println("`x` is equal to `1`.")
Selectors.runner(::Type{Second}, x) = println("`x` is not equal to `1`.")
```
"""
function runner end

"""
Define whether a selector case will "fallthrough" or not when successfully matched against.
By default matching is strict and does not fallthrough to subsequent selector cases.

```julia
# Adding a debugging selector case.
abstract type Debug <: MySelector end

# Insert prior to all other cases.
Selectors.order(::Type{Debug}) = 0.0

# Fallthrough to the next case on success.
Selectors.strict(::Type{Debug}) = false

# We always match, regardless of the value of `x`.
Selectors.matcher(::Type{Debug}, x) = true

# Print some debugging info.
Selectors.runner(::Type{Debug}, x) = @show x
```
"""
strict(::Type{T}) where {T <: AbstractSelector} = true

"""
Disable a particular case in a selector so that it is never used.

```julia
Selectors.disable(::Type{Debug}) = true
```
"""
disable(::Type{T}) where {T <: AbstractSelector} = false

"""
Call `Selectors.runner(T, args...)` where `T` is a subtype of
`MySelector` for which `matcher(T, args...)` is `true`.

```julia
Selectors.dispatch(MySelector, args...)
```
"""
function dispatch(::Type{T}, x...) where {T <: AbstractSelector}
    types = get!(selector_subtypes, T) do
        sort(leaf_subtypes(T); by = order)
    end
    for t in types
        if !disable(t) && matcher(t, x...)
            runner(t, x...)
            strict(t) && return
        end
    end
    return runner(T, x...)
end

"""
Return a list of all subtypes of `T` which do not have further subtypes.

The returned list includes subtypes of subtypes, and it does not distinguish
between concrete types (i.e. types which are guaranteed not to have subtypes)
and abstract types (which may or may not have subtypes).
"""
function leaf_subtypes(::Type{T}) where {T}
    stack = Type[T]
    leaves = Type[]
    while !isempty(stack)
        t = pop!(stack)
        s = subtypes(t)
        if length(s) == 0
            push!(leaves, t)
        else
            append!(stack, s)
        end
    end
    return leaves
end

# Under certain circumstances, the function `subtypes` can be very slow
# (https://github.com/JuliaLang/julia/issues/38079), so to ensure that
# `dispatch` remains fast we cache the results of `subtypes` here.
const selector_subtypes = Dict{Type, Vector}()

end
