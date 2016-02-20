
<a id='internal-documentation'></a>
# Internal Documentation


<a id='types'></a>
## Types


<a id='lapidarystate' href='#lapidarystate'>#</a>
**Type**

```
State
```

Used to store the current state of the markdown template expansion. This simplifies the [`expand`](internals.md#lapidaryexpand) methods by avoiding having to thread all the state between each call manually.

---

<a id='lapidarypath' href='#lapidarypath'>#</a>
**Type**

```
Path
```

Represents a file mapping from source file `.src` to destination file `.dst`.

---

<a id='lapidaryparsedpath' href='#lapidaryparsedpath'>#</a>
**Type**

```
ParsedPath
```

Same as [`Path`](internals.md#lapidarypath), but also includes the parsed content of the markdown file.

---

<a id='lapidaryheaderpath' href='#lapidaryheaderpath'>#</a>
**Type**

```
HeaderPath
```

Represents a file mapping from `.src` to `.dst` of a markdown header element. The `.nth` field tracks the ordering of the headers within the file.

---

<a id='lapidaryenv' href='#lapidaryenv'>#</a>
**Type**

```
Env(kwargs...)
```

Helper method used to simplidy the construction of [`Env`](internals.md#lapidaryenv) objects. Takes any number of keyword arguments. Note that unknown keyword arguments are discarded by this method.

```
Env
```

Stores all the state associated with a document. An instance of this type is threaded through the sequence of transformations used to build the document.

---

<a id='stages'></a>
## Stages


<a id='lapidarysetupbuilddirectory' href='#lapidarysetupbuilddirectory'>#</a>
**Type**

```
SetupBuildDirectory
```

Cleans out previous `build` directory and rebuilds the folder structure to match that of the `src` directory. Copies all non-markdown files from `src` to `build`.

---

<a id='lapidarycopyassetsdirectory' href='#lapidarycopyassetsdirectory'>#</a>
**Type**

```
CopyAssetsDirectory
```

Copies the contents of the Lapidary `assets` folder to `build/assets`.

Will throw an error if the directory already exists.

---

<a id='lapidaryparsetemplates' href='#lapidaryparsetemplates'>#</a>
**Type**

```
ParseTemplates
```

Reads the contents of each markdown file found in `src` and them into `Markdown.MD` objects using `Markdown.parse`.

---

<a id='lapidaryexpandtemplates' href='#lapidaryexpandtemplates'>#</a>
**Type**

```
ExpandTemplates
```

Runs all the expanders stored in `.expanders` on each element of the parsed markdown files.

---

<a id='lapidaryrundoctests' href='#lapidaryrundoctests'>#</a>
**Type**

```
RunDocTests
```

Finds all code blocks in an expanded document where the language is set to `julia` and tries to run them. Any failure will currently just terminate the entire document generation.

---

<a id='lapidarycrossreferencelinks' href='#lapidarycrossreferencelinks'>#</a>
**Type**

```
CrossReferenceLinks
```

Finds all `Markdown.Link` elements in an expanded document and tries to find where the link should point to. Will terminate the entire document generation process when a link cannot successfully be found.

---

<a id='lapidaryrenderdocument' href='#lapidaryrenderdocument'>#</a>
**Type**

```
RenderDocument
```

Write the contents of the expanded document tree to file. Currently only supports markdown output.

---

<a id='expanders'></a>
## Expanders


<a id='lapidaryexpand' href='#lapidaryexpand'>#</a>
**Function**

```
expand
```

Expand a single element, `block`, of a markdown file.

---

<a id='lapidarydefaultexpander' href='#lapidarydefaultexpander'>#</a>
**Type**

```
DefaultExpander
```

By default block expansion just pushes the block onto the end of the vector of expanded blocks.

---

<a id='lapidaryfindheaders' href='#lapidaryfindheaders'>#</a>
**Type**

```
FindHeaders
```

An expander that tracks all header elements in a document. The data gathered by this expander is used in later stages to build cross-reference links and tables of contents.

---

<a id='lapidarymetablock' href='#lapidarymetablock'>#</a>
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

<a id='lapidarymetanode' href='#lapidarymetanode'>#</a>
**Type**

```
MetaNode
```

Stores the parsed and evaluated key/value pairs found in a `{meta}` block.

---

<a id='lapidarydocsblock' href='#lapidarydocsblock'>#</a>
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

<a id='lapidarydocsnode' href='#lapidarydocsnode'>#</a>
**Type**

```
DocsNode
```

Stores the object and related docstring for a single object found in a `{docs}` block. When a `{docs}` block contains multiple entries then each one is expanded into a separate [`DocsNode`](internals.md#lapidarydocsnode).

---

<a id='lapidaryindexblock' href='#lapidaryindexblock'>#</a>
**Type**

```
IndexBlock
```

Expands code blocks where the first line contains `{index}`. Subsequent lines can contain key/value pairs relevant to the index. Currently `Pages = ["...", ..., "..."]` is supported for filtering the contents of the index based on source page.

Indexes are used to display links to all the docstrings, generated with `{docs}` blocks, on any number of pages.

---

<a id='lapidaryindexnode' href='#lapidaryindexnode'>#</a>
**Type**

```
IndexNode
```

`{index}` code blocks are expanded into this object which is used to store the key/value pairs needed to build the actual index during the later rendering state.

---

<a id='lapidarycontentsblock' href='#lapidarycontentsblock'>#</a>
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

<a id='lapidarycontentsnode' href='#lapidarycontentsnode'>#</a>
**Type**

```
ContentsNode
```

`{contents}` blocks are expanded into these objects, which, like with [`IndexNode`](internals.md#lapidaryindexnode), store the key/value pairs needed to render the contents during the later rendering stage.

---

<a id='utilities'></a>
## Utilities


<a id='lapidarycar' href='#lapidarycar'>#</a>
**Function**

```
car(x)
```

Head element of the `Tuple` `x`. See also [`cdr`](internals.md#lapidarycdr).

---

<a id='lapidarycdr' href='#lapidarycdr'>#</a>
**Function**

```
cdr(x)
```

Tail elements of the `Tuple` `x`. See also [`car`](internals.md#lapidarycar).

---

<a id='lapidaryassetsdir' href='#lapidaryassetsdir'>#</a>
**Function**

```
assetsdir()
```

Directory containing Lapidary asset files.

---

<a id='lapidarycurrentdir' href='#lapidarycurrentdir'>#</a>
**Function**

```
currentdir()
```

Returns the current source directory. When `isinteractive() ≡ true` then the present working directory, `pwd()` is returned instead.

---

<a id='lapidarywalk' href='#lapidarywalk'>#</a>
**Function**

```
walk(f, meta, element)
```

Scan a document tree and run function `f` on each `element` that is encountered.

---

<a id='lapidarylog' href='#lapidarylog'>#</a>
**Function**

```
log
```

Print a formatted message to `STDOUT`. Each document "stage" type must provide an implementation of this function.

---

<a id='lapidaryprocess' href='#lapidaryprocess'>#</a>
**Function**

```
process(env, stages...)
```

For each stage in `stages` execute stage with the given `env` as it's argument.

---

<a id='lapidaryparseblock' href='#lapidaryparseblock'>#</a>
**Function**

```
parseblock(code; skip = 0)
```

Returns an array of (expression, string) tuples for each complete toplevel expression from `code`. The `skip` keyword argument will drop the provided number of leading lines.

---

<a id='lapidaryobject' href='#lapidaryobject'>#</a>
**Macro**

```
@object(x)
```

Returns a normalised object that can be used to track which objects from the Julia docsystem have been spliced into the current document tree.

---

<a id='lapidarynodocs' href='#lapidarynodocs'>#</a>
**Function**

```
nodocs(x)
```

Does the document returned from the docsystem contain any useful documentation.

---

<a id='lapidarydoctest' href='#lapidarydoctest'>#</a>
**Function**

```
doctest(source)
```

Try to run the Julia source code found in `source`.

---
