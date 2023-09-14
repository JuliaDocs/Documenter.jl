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

### SVG output

```@example
Main.SVG_BIG
```

### `text/html` fallbacks

SVG with just `text/html` output (in practice, `DataFrame`s and such would fall into this category):

```@example
Main.SVG_HTML
```

SVG with both `text/html` and `image/svg+xml` MIME, in which case we expect to pick the image one (because text is too big) and write it to a file.

```@example
Main.SVG_MULTI
```
