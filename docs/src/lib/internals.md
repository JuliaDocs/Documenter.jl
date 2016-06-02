
```@meta
CurrentModule = Documenter
```

# Internal Documentation

## Contents

```@contents
Pages = ["internals.md"]
```

## Index

```@index
Pages = ["internals.md"]
```

## Anchors

```@docs
Anchors
Anchors.Anchor
Anchors.AnchorMap
Anchors.add!
Anchors.anchor
Anchors.exists
Anchors.isunique
```

## Builder

```@docs
Builder
Builder.DocumentPipeline
Builder.SetupBuildDirectory
Builder.CopyAssetsDirectory
Builder.ExpandTemplates
Builder.CrossReferences
Builder.CheckDocument
Builder.RenderDocument
```

## CrossReferences

```@docs
CrossReferences
CrossReferences.crossref
```

## DocChecks

```@docs
DocChecks
DocChecks.missingdocs
DocChecks.doctest
```

## Documents

```@docs
Documents
Documents.Document
Documents.Page
Documents.User
Documents.Internal
Documents.Globals
```

## Expanders

```@docs
Expanders
Expanders.ExpanderPipeline
Expanders.TrackHeaders
Expanders.MetaBlocks
Expanders.DocsBlocks
Expanders.AutoDocsBlocks
Expanders.EvalBlocks
Expanders.IndexBlocks
Expanders.ContentsBlocks
Expanders.ExampleBlocks
Expanders.REPLBlocks
```

## Formats

```@docs
Formats
Formats.Format
Formats.mimetype
```

## Generator

```@docs
Generator
Generator.savefile
Generator.make
Generator.gitignore
Generator.mkdocs
Generator.index
```

## Selectors

```@docs
Selectors
Selectors.AbstractSelector
Selectors.order
Selectors.matcher
Selectors.runner
Selectors.strict
Selectors.disable
Selectors.dispatch
```

## Walkers

```@docs
Walkers
Walkers.walk
```

## Writers

```@docs
Writers
Writers.render
```

## Utilities

```@docs
Utilities
Utilities.currentdir
Utilities.assetsdir
Utilities.check_kwargs
Utilities.slugify
Utilities.parseblock
Utilities.log
Utilities.warn
Utilities.logging
Utilities.submodules
Utilities.filterdocs
Utilities.Object
Utilities.object
Utilities.docs
Utilities.doccat
Utilities.nodocs
```
