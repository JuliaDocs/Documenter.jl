# Hosting Documentation

After going through the [Package Guide](@ref) and [Doctests](@ref) page you will need to
host the generated documentation somewhere for potential users to read. This guide will
describe how to setup automatic updates for your package docs using the Travis build service
and GitHub Pages. This is the same approach used by this package to host its own docs --
the docs you're currently reading.

!!! note

    Following this guide should be the *final* step you take after you are comfortable with
    the syntax and build process used by `Documenter.jl`. Only proceed with the steps
    outlined on this page once you have successfully used `mkdocs` locally to build your
    documentation.  `mkdocs` can typically be installed using `pip install mkdocs` in your
    terminal.

    This guide assumes that you already have GitHub and Travis accounts setup. If not then
    go set those up first and then return here.

## Overview

Once setup correctly the following will happen each time you push new updates to your
package repository:

- travis buildbots startup and run your tests;
- each buildbot will build the package docs using your `docs/make.jl` script;
- a single buildbot will then try to push the generated docs back to GitHub.

Note that the hosted documentation does not update when you make pull
requests; you see updates only when you merge to `master` or push new tags.

The following sections outline how to enable this for your own package.

## SSH Deploy Keys

Deploy keys provide push access to a *single* repository, to allow secure deployment of generated documentation from Travis to GitHub.

!!! note

    You will need several command line programs installed for the following steps to work.
    They are `which`, `git`, and `ssh-keygen`. Make sure these are installed before you
    begin this section.

Open a Julia REPL and import [`Documenter`](@ref).

```jlcon
julia> using Documenter
```

Then call the [`Travis.genkeys`](@ref) function as follows:

```jlcon
julia> Travis.genkeys("MyPackage")
```

where `"MyPackage"` is the name of the package you would like to create deploy keys for. The
output will look similar to the text below:

```
INFO: add the public key below to https://github.com/USER/REPO/settings/keys
      with read/write access:

[SSH PUBLIC KEY HERE]

INFO: add a secure environment variable named 'DOCUMENTER_KEY' to
      https://travis-ci.org/USER/REPO/settings with value:

[LONG BASE64 ENCODED PRIVATE KEY]
```

Follow the instructions that are printed out, namely:

 1. Add the public ssh key to your settings page for the GitHub repository that you are
    setting up by following the `.../settings/key` link provided. Click on **`Add deploy
    key`**, enter the name **`documenter`** as the title, and copy the public key into the
    **`Key`** field.  Note that you should include **no whitespace** when copying the key.
    Check **`Allow write access`** to allow Documenter to commit the generated documentation
    to the repo.

 2. Next add the long private key to the Travis settings page using the provided link. Again
    note that you should include **no whitespace** when copying the key. In the **`Environment
    Variables`** section add a key with the name `DOCUMENTER_KEY` and the value that was printed
    out. **Do not** set the variable to be displayed in the build log. Then click **`Add`**.

    !!! warning "Security warning"

        To reiterate: make sure that the "Display value in build log" option is **OFF** for
        the variable, so that it does not get printed when the tests run. This
        base64-encoded string contains the *unencrypted* private key that gives full write
        access to your repository, so it must be kept safe.  Also, make sure that you never
        expose this variable in your tests, nor merge any code that does. You can read more
        about Travis environment variables in [Travis User Documentation](https://docs.travis-ci.com/user/environment-variables/#Defining-Variables-in-Repository-Settings).

## `.travis.yml` Configuration

In the `after_success` section of the `.travis.yml` file, where code coverage is processed,
run your `docs/make.jl` file:

```yaml
after_success:
  - julia -e 'Pkg.add("Documenter")'
  - julia -e 'cd(Pkg.dir("PACKAGE_NAME")); include(joinpath("docs", "make.jl"))'
```

## The `deploydocs` Function

At the moment your `docs/make.jl` file probably only contains

```julia
using Documenter, PACKAGE_NAME

makedocs()
```

We'll need to add an additional call to this file after [`makedocs`](@ref). Add the
following at the end of the file:

```julia
deploydocs(
    repo = "github.com/USER_NAME/PACKAGE_NAME.jl.git"
)
```

where `USER_NAME` and `PACKAGE_NAME` must be set to the appropriate names. Note that `repo`
should not specify any protocol, i.e. it should not begin with `https://` or `git@`.

By default `deploydocs` will deploy the documentation from the `nightly` Julia build for
Linux. This can be changed using the `julia` and `osname` keywords as follows:

```julia
deploydocs(
    deps   = Deps.pip("mkdocs", "python-markdown-math"),
    repo   = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
    julia  = "0.4",
    osname = "osx"
)
```

This will deploy the docs from the OSX Julia 0.4 Travis build bot.

The keyword `deps` serves to provide the required dependencies to deploy
the documentation. In the example above we include the dependencies
[mkdocs](http://www.mkdocs.org)
and [`python-markdown-math`](https://github.com/mitya57/python-markdown-math).
The former makes sure that MkDocs is installed to deploy the documentation,
and the latter provides the `mdx_math` markdown extension to exploit MathJax
rendering of latex equations in markdown. Other dependencies should be
included here.

See the [`deploydocs`](@ref) function documentation for more details.

## The MkDocs `mkdocs.yml` File

We'll be using [MkDocs](http://www.mkdocs.org) to convert the markdown files generated by
Documenter to HTML. (This, of course, is not the only option you have for this step. Any
markdown to HTML converter should work fine with some amount of setting up.)

Add an `mkdocs.yml` file to your `docs/` directory with the following content:

```yaml
site_name:        PACKAGE_NAME.jl
repo_url:         https://github.com/USER_NAME/PACKAGE_NAME.jl
site_description: Description...
site_author:      USER_NAME

theme: readthedocs

extra_css:
  - assets/Documenter.css

extra_javascript:
  - https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=TeX-AMS_HTML
  - assets/mathjaxhelper.js

markdown_extensions:
  - extra
  - tables
  - fenced_code
  - mdx_math

docs_dir: 'build'

pages:
  - Home: index.md
```

This is only a basic skeleton. Read through the MkDocs documentation if you would like to
know more about the available settings.

## `.gitignore`

Add the following to your package's `.gitignore` file

```
docs/build/
docs/site/
```

These are needed to avoid committing generated content to your repository.

## `gh-pages` Branch

By default, Documenter pushes documentation to the `gh-pages` branch. If the branch does not
exist it will be created automatically by [`deploydocs`](@ref). If does exist then
Documenter simply adds an additional commit with the built documentation. You should be
aware that Documenter may overwrite existing content without warning.

If you wish to create the `gh-pages` branch manually the that can be done following
[these instructions](https://coderwall.com/p/0n3soa/create-a-disconnected-git-branch).

## Documentation Versions

When documentation is generated it is stored in one of the following folders:

- `latest` stores the most recent documentation that is committed to the `master` branch.

- `stable` stores the most recent documentation from a tagged commit. Older tagged versions
  are stored in directories named after their tags. These tagged directories are persistent
  and must be manually removed from the `gh-pages` branch if necessary.

Unless a custom domain is being used, the `stable` and `latest` pages are found at:

```markdown
https://USER_NAME.github.io/PACKAGE_NAME.jl/stable
https://USER_NAME.github.io/PACKAGE_NAME.jl/latest
```

Once your documentation has been pushed to the `gh-pages` branch you should add links to
your `README.md` pointing to the `stable` and `latest` documentation URLs. It is common
practice to make use of "badges" similar to those used for Travis and AppVeyor build
statuses or code coverage. Adding the following to your package `README.md` should be all
that is necessary:

```markdown
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://USER_NAME.github.io/PACKAGE_NAME.jl/stable)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://USER_NAME.github.io/PACKAGE_NAME.jl/latest)
```

`PACKAGE_NAME` and `USER_NAME` should be replaced with their appropriate values. The colour
and text of the image can be changed by altering `docs-stable-blue` as described on
[shields.io](http://shields.io), though it is recommended that package authors follow this
standard to make it easier for potential users to find documentation links across multiple
package README files.

---

**Final Remarks**

That should be all that is needed to enable automatic documentation building. Pushing new
commits to your `master` branch should trigger doc builds. **Note that other branches do not
trigger these builds and neither do pull requests by potential contributors.**

If you would like to see a more complete example of how this process is setup then take a
look at this package's repository for some inspiration.
