# Testing

We set up some test code and create an object with a finalizer.

```@setup
@eval Main finalizer_count = [0]

mutable struct MyMutableStruct
  bar
  function MyMutableStruct(bar)
      x = new(bar)
      finalizer(x) do y
        Main.finalizer_count[1] += 1
      end
  end
end

a = MyMutableStruct(1)
```

Once Documenter is finished processing this page, it should remove the
reference to the object `a` and a subsequent garbage collection should free
it, which we can later test by observing the value of `Main.finalizer_count`.

# Example blocks

```@example example-1
a = 1 # simple assignment
```

```@example example-2
nothing = 1 # it is possible to use `nothing` as a variable name
a = 2
```

```@example example-3
nothing() = 3 # it is possible to use `nothing` as a function name
a = nothing()
```

```@example example-4
@static if VERSION >= v"1.8"
typed::String = "string" # it is possible to use `::` to specify the type of a variable
end
```

```@example example-5
const a = 5 # it is possible to use `const` to define a constant
```

Once Documenter is finished processing this page, it attempts to remove the 
variables defined in the example blocks. Documenter should not error when 
processing those example blocks even if it cannot remove the variables.