<a id='Internal%20Documentation-1'></a>

# Internal Documentation

<a id='Lapidary.process%21-1'></a>

<a href='#Lapidary.process%21-1'> # </a>**Function**

```
process!(doc::Document)
```

Process a `Document` object by calling each `pass` from `doc.passes` on it in turn.

A `pass` consists of a sequence of [`AbstractAction`](internals.md#Lapidary.AbstractAction-1)s each of which apply a single transformation to the `doc` object such as autolinking cross-references found in the pages of the `Document` or running doctests on all the code blocks.
<hr></hr>
<a id='Lapidary.AbstractAction-1'></a>

<a href='#Lapidary.AbstractAction-1'> # </a>**Type**

```
AbstractAction
```

Represents a single transformation to be applied to a `Document`. Custom transformation types must subtype from this type, i.e.

```julia
immutable CustomAction <: AbstractAction end
```

For each custom `AbstractAction` type defined one or more 4-arg [`process!`](internals.md#Lapidary.process%21-1) methods must be defined with the signature

```julia
process!(::CustomAction, page::page, content::Vector, block::Any) = ...
```

where

  * `block` is the current part of the document being processed. This could be a header,   paragraph, code block, metadata, table of contents, etc.
  * `content` is the vector into which the results of the transformation should be pushed if   there are any. So when, for example, doctesting a code block (the `block`) it should then   be pushed onto the end of `content` to save it for the next pass.
  * `page` is the current `Page` object in which the `block` is located. This object has   access to the rest of the document structure via `page.root`. `page.root` in turn contains   a vector of all `Page` objects.
<hr></hr>
<a id='Lapidary.DefaultAction-1'></a>

<a href='#Lapidary.DefaultAction-1'> # </a>**Type**

```
DefaultAction
```

Handles any case not explicitly handled by a custom `AbstractAction`. When called on a block it will simply add it to the output `content` vector thus not "losing" any blocks for subsequent passes.
<hr></hr>
<a id='Lapidary.PassOne-1'></a>

<a href='#Lapidary.PassOne-1'> # </a>**Constant**

```
PassOne
```

"Pre-processing" steps such as cleaning the build directory, parsing metadata, docs, and generating header anchors. Actions in this pass generally collect information needed for later passes.
<hr></hr>
<a id='Lapidary.PassTwo-1'></a>

<a href='#Lapidary.PassTwo-1'> # </a>**Constant**

```
PassTwo
```

The "main" pass where information gathered in the previous stage is used to link together different pages and blocks. Actions such as cross-referencing and generating tables of contents are applied during this pass.
<hr></hr>
<a id='Lapidary.PassThree-1'></a>

<a href='#Lapidary.PassThree-1'> # </a>**Constant**

```
PassThree
```

The "finalisation" pass where the output directory is setup and all pages and there content are rendered to actual files.
<hr></hr>
