# Contributing

This page details the some of the guidelines that should be followed when contributing to this package.


## Branches

From `Documenter` version `0.3` onwards `release-*` branches are used for tagged minor versions of this package. This follows the same approach used in the main Julia repository, albeit on a much more modest scale.

Please open pull requests against the `master` branch rather than any of the `release-*` branches whenever possible.

### Backports

Bug fixes are backported to the `release-*` branches using `git cherry-pick -x` by a JuliaDocs member and will become available in point releases of that particular minor version of the package.

Feel free to nominate commits that should be backported by opening an issue. Requests for new point releases to be tagged in `METADATA.jl` can also be made in the same way.

### `release-*` branches

  * Each new minor version `x.y.0` gets a branch called `release-x.y` (a [protected branch](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)).
  * New versions are usually tagged only from the `release-x.y` branches.
  * For patch releases, changes get backported to the `release-x.y` branch via a single PR with the standard name "Backports for x.y.z" and label ["Type: Backport"](https://github.com/JuliaDocs/Documenter.jl/pulls?q=label%3A%22Type%3A+Backport%22). The PR message links to all the PRs that are providing commits to the backport. The PR gets merged as a merge commit (i.e. not squashed).
  * The old `release-*` branches may be removed once they have outlived their usefulness.
  * Patch version [milestones](https://github.com/JuliaDocs/Documenter.jl/milestones) are used to keep track of which PRs get backported etc.


## Style Guide

Follow the style of the surrounding text when making changes. When adding new features please try to stick to the following points whenever applicable.

### Julia

Documenter uses [Runic.jl](https://github.com/fredrikekre/Runic.jl) for code
formatting. In addition, the following style guidelines should be followed:

  * use `function ... end` when a method definition contains more than one toplevel expression;
  * related short-form method definitions don't need a new line between them;
  * unrelated or long-form method definitions must have a blank line separating each one;
  * files containing a single `module ... end` must be named after the module;
  * method arguments should be ordered based on the amount of usage within the method body;
  * methods extended from other modules must follow their inherited argument order, not the above rule;
  * avoid dense expressions where possible e.g. prefer nested `if`s over complex nested `?`s;
  * do not use multiline comments (`#=` and `=#`);
  * wrap long lines as near to 92 characters as possible, this includes docstrings;
  * follow the standard naming conventions used in `Base`.

### Markdown

  * Use unbalanced `#` headers, i.e. no `#` on the right hand side of the header text;
  * include a single blank line between toplevel blocks;
  * unordered lists must use `*` bullets with two preceding spaces;
  * do *not* hard wrap lines;
  * use emphasis (`*`) and bold (`**`) sparingly;
  * always use fenced code blocks instead of indented blocks;
  * follow the conventions outlined in the Julia documentation page on documentation.

## Changelog

All pull requests that make user visible changes should have a changelog entry
formatted according to the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
style

## Tests

### Unit tests

As is conventional for Julia packages, unit tests are located at `test/*.jl` with the entrypoint
`test/runtests.jl`.

### End to end testing 

Tests that build example package docs from source and inspect the results (end to end tests) are
located in `/test/examples`. The main entry points are `test/examples/make.jl` for building and 
`test/examples/test.jl` for doing some basic checks on the generated outputs.
