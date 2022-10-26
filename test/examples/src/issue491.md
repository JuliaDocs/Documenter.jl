# Issue 491

Tests that code-like blocks are expanded in nested Markdown contexts.

- Recurse into lists:

  ```@repl
  item = nothing
  ```

  1. More than single layer of nesting as well:

     ```@repl
     item_item = nothing
     ```

!!! note
    Recurse into admonitions:
    ```@repl
    admonition = nothing
    ```
    > And also block quotes
    > ```@repl
    > admonition_blockquote = nothing
    > ```

!!! note
    Test the different types of code-like blocks:

    ```@eval
    "expanded_"*"eval"
    ```

    ```@example
    println("expanded_", "example")
    ```

    ```@setup setup
    var = "expanded_"*"setup"
    ```

    ```@example setup
    println(var)
    ```

    ```@raw html
    <p>expanded_raw</p>
    ```
