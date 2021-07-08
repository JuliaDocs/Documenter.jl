# `@repl`, `@example`, and `@eval` have correct `LineNumberNode`s inserted

Add new things at the bottom!!

```@repl
println("@__FILE__ should be REPL[1]: ", @__FILE__)
println("@__FILE__ should be REPL[2]: ", @__FILE__)
println("@__LINE__ should be 1: ", @__LINE__)
@warn "@__FILE__ should be REPL[4] and @__LINE__ 1"
begin
    println("@__FILE__ should be REPL[5]: ", @__FILE__)
    println("@__FILE__ should be REPL[5]: ", @__FILE__)
    println("@__LINE__ should be 4: ", @__LINE__)
    @warn "@__FILE__ should be REPL[5] and @__LINE__ 5"
end
```

```@example
println("@__FILE__ should be linenumbers.md: ", @__FILE__)
println("@__LINE__ should be 20: ", @__LINE__)
@warn "@__FILE__ should be linenumbers.md and @__LINE__ 21"
begin
    println("@__FILE__ should be linenumbers.md: ", @__FILE__)
    println("@__LINE__ should be 24: ", @__LINE__)
    @warn "@__FILE__ should be linenumbers.md and @__LINE__ 25"
end
```

````@eval
import Markdown
Markdown.parse("""```
\$(@__FILE__):\$(@__LINE__) should be linenumbers.md:32: $(@__FILE__):$(@__LINE__)
\$(@__FILE__):\$(@__LINE__) should be linenumbers.md:33: $(@__FILE__):$(@__LINE__)
```
""")
````
