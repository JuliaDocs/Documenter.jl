# Contributing

This page details the some of the guidelines that should be followed when contributing to this package.

## Branches

From `Documenter` version `0.3` onwards `release-*` branches are used for tagged minor versions of this package. This follows the same approach used in the main Julia repository, albeit on a much more modest scale.

Please open pull requests against the `master` branch rather than any of the `release-*` branches whenever possible.

## Backports

Bug fixes are backported to the `release-*` branches using `git cherry-pick -x` by a JuliaDocs member and will become available in point releases of that particular minor version of the package.

Feel free to nominate commits that should be backported by opening an issue. Requests for new point releases to be tagged in `METADATA.jl` can also be made in the same way.

## Style Guide

Follow the style of the surrounding text when making changes. When adding new features please try to stick to the following points whenever applicable.

### Julia

  * 4-space indentation;
  * modules spanning entire files should not be indented, but modules that have surrounding code should;
  * no blank lines at the start or end of files;
  * do not manually align syntax such as `=` or `::` over adjacent lines;
  * use `local` to define new local variables so that they are easier to locate;
  * use `function ... end` when a method definition contains more than one toplevel expression;
  * related short-form method definitions don't need a new line between them;
  * unrelated or long-form method definitions must have a blank line separating each one;
  * surround all binary operators with whitespace except for `::`, `^`, and `:`;
  * files containing a single `module ... end` must be named after the module;
  * method arguments should be ordered based on the amount of usage within the method body;
  * methods extended from other modules must follow their inherited argument order, not the above rule;
  * explicit `return` should be preferred except in short-form method definitions;
  * avoid dense expressions where possible e.g. prefer nested `if`s over complex nested `?`s;
  * include a trailing `,` in vectors, tuples, or method calls that span several lines;
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
