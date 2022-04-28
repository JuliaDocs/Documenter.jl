# Code block prerendering using NodeJS

```julia
function f()
    print("hello, world")
end
```

```julia-repl
julia> function f()
           print("hello, world")
       end
```

```llvm
;  @ int.jl:87 within `+'
define i64 @"julia_+_212"(i64 signext %0, i64 signext %1) {
top:
  %2 = add i64 %1, %0
  ret i64 %2
}
```
