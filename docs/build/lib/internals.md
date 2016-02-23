
<a id='internal-documentation'></a>
# Internal Documentation


<a id='types'></a>
## Types


<a id='Lapidary.State' href='#Lapidary.State'>#</a>
**Type**

```
State
```

Used to store the current state of the markdown template expansion. This simplifies the [`expand`](internals.md#Lapidary.expand) methods by avoiding having to thread all the state between each call manually.

---

<a id='Lapidary.Path' href='#Lapidary.Path'>#</a>
**Type**

```
Path
```

Represents a file mapping from source file `.src` to destination file `.dst`.

---

<a id='Lapidary.ParsedPath' href='#Lapidary.ParsedPath'>#</a>
**Type**

```
ParsedPath
```

Same as [`Path`](internals.md#Lapidary.Path), but also includes the parsed content of the markdown file.

---

<a id='Lapidary.HeaderPath' href='#Lapidary.HeaderPath'>#</a>
**Type**

```
HeaderPath
```

Represents a file mapping from `.src` to `.dst` of a markdown header element. The `.nth` field tracks the ordering of the headers within the file.

---

<a id='Lapidary.Env' href='#Lapidary.Env'>#</a>
**Type**

```
Env(kwargs...)
```

Helper method used to simplidy the construction of [`Env`](internals.md#Lapidary.Env) objects. Takes any number of keyword arguments. Note that unknown keyword arguments are discarded by this method.

```
Env
```

Stores all the state associated with a document. An instance of this type is threaded through the sequence of transformations used to build the document.

---

<a id='stages'></a>
## Stages


<a id='Lapidary.SetupBuildDirectory' href='#Lapidary.SetupBuildDirectory'>#</a>
**Type**

```
SetupBuildDirectory
```

Cleans out previous `build` directory and rebuilds the folder structure to match that of the `src` directory. Copies all non-markdown files from `src` to `build`.

---

<a id='Lapidary.CopyAssetsDirectory' href='#Lapidary.CopyAssetsDirectory'>#</a>
**Type**

```
CopyAssetsDirectory
```

Copies the contents of the Lapidary `assets` folder to `build/assets`.

Will throw an error if the directory already exists.

---

<a id='Lapidary.ParseTemplates' href='#Lapidary.ParseTemplates'>#</a>
**Type**

```
ParseTemplates
```

Reads the contents of each markdown file found in `src` and them into `Markdown.MD` objects using `Markdown.parse`.

---

<a id='Lapidary.ExpandTemplates' href='#Lapidary.ExpandTemplates'>#</a>
**Type**

```
ExpandTemplates
```

Runs all the expanders stored in `.expanders` on each element of the parsed markdown files.

---

<a id='Lapidary.RunDocTests' href='#Lapidary.RunDocTests'>#</a>
**Type**

```
RunDocTests
```

Finds all code blocks in an expanded document where the language is set to `julia` and tries to run them. Any failure will currently just terminate the entire document generation.

---

<a id='Lapidary.CheckDocs' href='#Lapidary.CheckDocs'>#</a>
**Type**

```
CheckDocs
```

Consistency checks for the generated documentation. Have all the available docs from the specified modules been added to the external docs?

---

<a id='Lapidary.CrossReferenceLinks' href='#Lapidary.CrossReferenceLinks'>#</a>
**Type**

```
CrossReferenceLinks
```

Finds all `Markdown.Link` elements in an expanded document and tries to find where the link should point to. Will terminate the entire document generation process when a link cannot successfully be found.

---

<a id='Lapidary.RenderDocument' href='#Lapidary.RenderDocument'>#</a>
**Type**

```
RenderDocument
```

Write the contents of the expanded document tree to file. Currently only supports markdown output.

---

<a id='expanders'></a>
## Expanders


<a id='Lapidary.expand' href='#Lapidary.expand'>#</a>
**Function**

```
expand
```

Expand a single element, `block`, of a markdown file.

---

<a id='Lapidary.DefaultExpander' href='#Lapidary.DefaultExpander'>#</a>
**Type**

```
DefaultExpander
```

By default block expansion just pushes the block onto the end of the vector of expanded blocks.

---

<a id='Lapidary.FindHeaders' href='#Lapidary.FindHeaders'>#</a>
**Type**

```
FindHeaders
```

An expander that tracks all header elements in a document. The data gathered by this expander is used in later stages to build cross-reference links and tables of contents.

---

<a id='Lapidary.MetaBlock' href='#Lapidary.MetaBlock'>#</a>
**Type**

```
MetaBlock
```

Expands markdown code blocks where the first line contains `{meta}`. The expander parses the contents of the block expecting key/value pairs such as

```
{meta}
CurrentModule = Lapidary
```

Note that all syntax used in the block must be valid Julia syntax.

---

<a id='Lapidary.MetaNode' href='#Lapidary.MetaNode'>#</a>
**Type**

```
MetaNode
```

Stores the parsed and evaluated key/value pairs found in a `{meta}` block.

---

<a id='Lapidary.DocsBlock' href='#Lapidary.DocsBlock'>#</a>
**Type**

```
DocsBlock
```

Expands code blocks where the first line contains `{docs}`. Subsequent lines should be names of objects whose documentation should be retrieved from the Julia docsystem.

```
{docs}
foo
bar(x, y)
Baz.@baz
```

Each object is evaluated in the `current_module()` or `CurrentModule` if that has been set in a `{meta}` block of the current page prior to the `{docs}` block.

---

<a id='Lapidary.DocsNode' href='#Lapidary.DocsNode'>#</a>
**Type**

```
DocsNode
```

Stores the object and related docstring for a single object found in a `{docs}` block. When a `{docs}` block contains multiple entries then each one is expanded into a separate [`DocsNode`](internals.md#Lapidary.DocsNode).

---

<a id='Lapidary.IndexBlock' href='#Lapidary.IndexBlock'>#</a>
**Type**

```
IndexBlock
```

Expands code blocks where the first line contains `{index}`. Subsequent lines can contain key/value pairs relevant to the index. Currently `Pages = ["...", ..., "..."]` is supported for filtering the contents of the index based on source page.

Indexes are used to display links to all the docstrings, generated with `{docs}` blocks, on any number of pages.

---

<a id='Lapidary.IndexNode' href='#Lapidary.IndexNode'>#</a>
**Type**

```
IndexNode
```

`{index}` code blocks are expanded into this object which is used to store the key/value pairs needed to build the actual index during the later rendering state.

---

<a id='Lapidary.ContentsBlock' href='#Lapidary.ContentsBlock'>#</a>
**Type**

```
ContentsBlock
```

Expands code blocks where the first line contains `{contents}`. Subsequent lines can, like the `{index}` block, contains key/value pairs. Supported pairs are

```
Pages = ["...", ..., "..."]
Depth = 2
```

where `Pages` acts the same as for `{index}` and `Depth` limits the header level displayed in the generated contents.

Contents blocks are used to a display nested list of the headers found in one or more pages.

---

<a id='Lapidary.ContentsNode' href='#Lapidary.ContentsNode'>#</a>
**Type**

```
ContentsNode
```

`{contents}` blocks are expanded into these objects, which, like with [`IndexNode`](internals.md#Lapidary.IndexNode), store the key/value pairs needed to render the contents during the later rendering stage.

---

<a id='utilities'></a>
## Utilities


<a id='Lapidary.car' href='#Lapidary.car'>#</a>
**Function**

```
car(x)
```

Head element of the `Tuple` `x`. See also [`cdr`](internals.md#Lapidary.cdr).

---

<a id='Lapidary.cdr' href='#Lapidary.cdr'>#</a>
**Function**

```
cdr(x)
```

Tail elements of the `Tuple` `x`. See also [`car`](internals.md#Lapidary.car).

---

<a id='Lapidary.assetsdir' href='#Lapidary.assetsdir'>#</a>
**Function**

```
assetsdir()
```

Directory containing Lapidary asset files.

---

<a id='Lapidary.currentdir' href='#Lapidary.currentdir'>#</a>
**Function**

```
currentdir()
```

Returns the current source directory. When `isinteractive() ≡ true` then the present working directory, `pwd()` is returned instead.

---

<a id='Lapidary.walk' href='#Lapidary.walk'>#</a>
**Function**

```
walk(f, meta, element)
```

Scan a document tree and run function `f` on each `element` that is encountered.

---

<a id='Lapidary.log' href='#Lapidary.log'>#</a>
**Function**

```
log
```

Print a formatted message to `STDOUT`. Each document "stage" type must provide an implementation of this function.

---

<a id='Lapidary.process' href='#Lapidary.process'>#</a>
**Function**

```
process(env, stages...)
```

For each stage in `stages` execute stage with the given `env` as it's argument.

---

<a id='Lapidary.parseblock' href='#Lapidary.parseblock'>#</a>
**Function**

```
parseblock(code; skip = 0)
```

Returns an array of (expression, string) tuples for each complete toplevel expression from `code`. The `skip` keyword argument will drop the provided number of leading lines.

---

<a id='Lapidary.nodocs' href='#Lapidary.nodocs'>#</a>
**Function**

```
nodocs(x)
```

Does the document returned from the docsystem contain any useful documentation.

---

<a id='Lapidary.doctest' href='#Lapidary.doctest'>#</a>
**Function**

```
doctest(source)
```

Try to run the Julia source code found in `source`.

---

<a id='Lapidary.slugify' href='#Lapidary.slugify'>#</a>
**Function**

```
slugify(s)
```

Slugify a string `s` by removing special characters. Used in the url generation process.

---
