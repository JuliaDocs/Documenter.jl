module DummyModule

"""
    func1(x)

This is the docstring for `func1`. It references [`func2`](@ref).
"""
func1(x) = x

"""
    func2(y)

This is the docstring for `func2`.
"""
func2(y) = y

"""
    MyType

A custom type.
"""
struct MyType
    x::Int
end

end
