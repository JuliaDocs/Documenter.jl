# Example stdout

Checking that `@example` output is contained in a specific HTML class.

!!! warning

    This file should contain exactly one `@example` for the test to work.

```@example
println("hello")
```

## `@example` outputs to file

```@example
Main.AT_EXAMPLE_FILES[("png", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("png", :tiny)]
```
```@example
Main.AT_EXAMPLE_FILES[("webp", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("webp", :tiny)]
```
```@example
Main.AT_EXAMPLE_FILES[("gif", :big)]
```
```@example
Main.AT_EXAMPLE_FILES[("jpeg", :tiny)]
```
