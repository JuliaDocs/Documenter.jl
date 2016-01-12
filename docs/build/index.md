<a id='Main.Lapidary-1'></a>

<a href='#Main.Lapidary-1'> # </a>**Constant**

# Lapidary

A documentation generator for Julia.

[![Build Status](https://travis-ci.org/MichaelHatherly/Lapidary.jl.svg?branch=master)](https://travis-ci.org/MichaelHatherly/Lapidary.jl) [![codecov.io](http://codecov.io/github/MichaelHatherly/Lapidary.jl/coverage.svg?branch=master)](http://codecov.io/github/MichaelHatherly/Lapidary.jl?branch=master)

## Brief Overview

**Doctests**

Any code block with `.language` set to `"julia"` containing either REPL prompts, `julia>`, or an `# output:` comment. For example:

````
```julia
julia> a = 1
1

julia> b = 2;

julia> a + b
3
```
````

or

````
```julia
a = 1
b = 2
a + b

# output:

3
```
````

Errors can be checked for using the `{throws ErrorName}` syntax, i.e.

````
```julia
julia> div(1, 0)

    {throws DivideError}

```
````

**Docstring Splicing**

Docstrings for objects documented using Julia's docsystem can be spliced into the markdown files using code blocks containing `{docs}` as their first line:

````
```
{docs}
foo
bar
baz
```
````

Operators must be enclosed, i.e. `(+)`.

**Metadata**

Metadata, such as the current module, can be set for a page using the `{meta}` code block:

````
```
{meta}
CurrentModule = Base
```
````

Changing the module allows one to avoid having to fully qualify every object spliced into a `{docs}` block.

**Contents & Index**

Table of contents and docstring indexes can be automatically generated using either `{contents}` or `{index}` code blocks. These code blocks shouldn't contain any other text.

````
```
{contents}
```
````

expands to a nested list of all headers in all files found in the `src` directory. The depth of headers to be displayed can be set with

````
```
{meta}
ContentsDepth = 2
```
````

prior to the `{contents}` block.

````
```
{index}
```
````

expands into a list of all documented objects spliced into the files found in the `src` directory. The module's to be included can be limited using

````
```
{meta}
IndexModules = [Foo, Bar]
```
````

prior to the `{index}` block.

**Auto Links**

Automatic cross-referencing uses markdown link syntax with the `url` set to `{ref}`, i.e

```
This is the [Introduction]({ref}).
```

which links to the first header called `"Introduction"` in any file found in `src`.

Spliced docstrings can be linked to using inline code syntax for the text of a link, i.e

```
This is the [`foo`]({ref}) function.
```

which will link to where `foo` was spliced into a `{docs}` block.

**Building Docs**

See the `src/build.jl` file for the standard build file used by Lapidary.
<hr></hr>
