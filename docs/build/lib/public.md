
<a id='public-documentation'></a>
# Public Documentation


<a id='Lapidary.makedocs' href='#Lapidary.makedocs'>#</a>
**Function**

```
makedocs(
    root    = "<current-directory>",
    source  = "src",
    build   = "build",
    clean   = true,
    doctest = true,
    modules = Module[],
)
```

Combines markdown files and inline docstrings into an interlinked document.

In most cases [`makedocs`](public.md#Lapidary.makedocs) should be run from a `make.jl` file:

```julia
using Lapidary

makedocs(
    # keywords...
)
```

which is then run from the command line with:

```
$ julia make.jl
```

The folder structure that [`makedocs`](public.md#Lapidary.makedocs) expects looks like:

```
docs/
    build/
    src/
    make.jl
```

**Keywords**

**`root`** is the directory from which `makedocs` should run. When run from a `make.jl` file this keyword does not need to be set. It is, for the most part, needed when repeatedly running `makedocs` from the Julia REPL like so:

```
julia> makedocs(root = Pkg.dir("MyPackage", "docs"))
```

**`source`** is the directory, relative to `root`, where the markdown source files are read from. By convention this folder is called `src`. Note that any non-markdown files stored in `source` are copied over to the build directory when [`makedocs`](public.md#Lapidary.makedocs) is run.

**`build`** is the directory, relative to `root`, into which generated files and folders are written when [`makedocs`](public.md#Lapidary.makedocs) is run. The name of the build directory is, by convention, called `build`, though, like with `source`, users are free to change this to anything else to better suit their project needs.

**`clean`** tells [`makedocs`](public.md#Lapidary.makedocs) whether to remove all the content from the `build` folder prior to generating new content from `source`. By default this is set to `true`.

**`doctest`** instructs [`makedocs`](public.md#Lapidary.makedocs) on whether to try to test Julia code blocks that are encountered in the generated document. By default this keyword is set to `true`. Doctesting should only ever be disabled when initially setting up a newly developed package where the developer is just trying to get their package and documentation structure correct. After that, it's encouraged to always make sure that documentation examples are runnable and produce the expected results. See the [Doctests](../man/doctests.md#doctests) manual section for details about running doctests.

**`modules`** specifies a vector of modules that should be documented in `source`. If any inline docstrings from those modules are seen to be missing from the generated content then a warning will be printed during execution of [`makedocs`](public.md#Lapidary.makedocs). By default no modules are passed to `modules` and so no warnings will appear. This setting can be used as an indicator of the "coverage" of the generated documentation.

For example Lapidary's `make.jl` file contains:

```julia
using Lapidary

makedocs(
    modules = [Lapidary],
    clean   = false
)
```

and so any docstring from the module `Lapidary` that is not spliced into the generated documentation in `build` will raise a warning.

**Notes**

A guide detailing how to document a package using Lapidary's [`makedocs`](public.md#Lapidary.makedocs) is provided in the [Usage](../man/guide.md#usage) section of the manual.

---
