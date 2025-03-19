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
