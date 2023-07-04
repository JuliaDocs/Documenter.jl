# Documenter & semantic versioning

Documenter, [like any good Julia package](https://pkgdocs.julialang.org/v1/compatibility/#Version-specifier-format), follows [semantic versioning](https://semver.org/).
As such, and as the package is currently in the `v1.x` era of its lifecycle, any changes in Documenter should not break any existing functionality.[^1]

[^1]: Eventually, of course, Documenter `2.0` may break everything. But we don't expect a breaking release in the near future.

However, Documenter is relatively complex, and it can sometimes be unclear what constitutes a _breaking change_.
For example, is changing the CSS classes in the HTML themes allowed?
What if the user relied on a CSS class in an `@raw html`-block?
If their HTML is no longer rendered correctly, is that a breaking change?
Is completely changing the LaTeX compiler a breaking change?
What if it breaks a PDF build somewhere due to some math block using a feature that only works with `pdflatex`?

This page aims to clarify what **is** and **is not** covered by the Documenter semver guarantees, both as information for users, and as guidance for developers.

!!! note "This page is not complete!"

    If you need to rely on something that is currently an internal API or undocumented behavior, open an issue or a pull request to get it documented!
    There is a good chance that the behavior is already a _de factor_ semver guarantee, or can easily be cleaned up and made public API.
    The goal is to, over time, add and document additional semver guarantees.


## Documenter's API guarantees

The following APIs and behaviors are guaranteed not to change:

* Standard promises about the Julia APIs (public Documenter functions and their documented arguments).
  In a nutshell, any `make.jl` making use of just public, documented parts of the Documenter API should always continue working (i.e. builds should complete).
* Any explicitly documented behaviors (e.g. the way Documenter [determines remote repository links is documented](@ref "Remote links")).
  The behavior of undocumented edge cases may change, but only in accordance with what is documented.

!!! note "Experimental APIs"

    Note that some APIs may explicitly marked experimental.
    In that case, you can only rely on them _withing a minor version_.
    The next minor version release may completely change or remove experimental features and APIs.


## What is not covered by semver

In principle, anything that is not covered by the previous section is, by definition, _not_ part of the public API and is _not_ guaranteed not to break.

However, it is worth mentioning a few things explicitly, in particular things that are currently not part of the API, but should be added in the future:

* Any time you hook into Documenter's Julia internals some way.
  This includes hooking into the seemingly extensible parts of the internals, such as adding additional build steps, or renderers.
  The long-term aim here is to create clean plugin APIs, but it is unlikely we'll be able to keep the current internals for that.
* The HTML, TeX, or file structure of the generated documents (unless explicitly documented).
  However, there are many _de facto_ guarantees here that should get documented over time (e.g. for custom themes).
* Anything explicitly marked experimental (see the note above).


!!! note "Patch versions are probably okay"

    If you are relying on some non-semver behaviors, features, or internals, it probably fine to expect things not to break _within a patch release_.
    In this case, you should add a `[compat]` entry to your `Project.toml` files with a [tilde specifier](https://pkgdocs.julialang.org/v1/compatibility/#Tilde-specifiers) fixing Documenter's to a specific minor version, e.g.

    ```toml
    Documenter = "~1.X"
    ```

    where `X` is the minor version you are developing against.

    Alternatively, if this is for package documentation, and your `docs/make.jl` script is relying on some non-semver behavior, you can also check in a `docs/Manifest.toml` file to fully fix the Documenter version.
    However, it may still be a good idea to include the version bound in the `docs/Project.toml` file, just as documentation for maintainers.
