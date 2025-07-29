module SampleModule

"""
    sample_function(x)

An example function.
"""
function sample_function(x)
    return x
end

"""
    another_function(y, z)

Another function with more complex examples.

# Examples
```jldoctest
julia> another_function(1, 2)
3
```
"""
function another_function(y, z)
    return y + z
end

end
