# Hosting Documentation

After going through the [Package Guide](@ref) and [Doctests](@ref) page you will need to
host the generated documentation somewhere for potential users to read. This guide will
describe how to setup automatic updates for your package docs using the Travis build service
and GitHub Pages. This is the same approach used by this package to host its own docs --
the docs you're currently reading.

!!! note

    Following this guide should be the *final* step you take after you are comfortable with
    the syntax and build process used by `Documenter.jl`. It is recommended that you only
    proceed with the steps outlined here once you have successfully managed to build your
    documentation locally with Documenter.

    This guide assumes that you already have [GitHub](https://github.com/) and
    [Travis](https://travis-ci.com/) accounts setup. If not then go set those up first and
    then return here.


## Overview

Once set up correctly, the following will happen each time you push new updates to your
package repository:

- Travis buildbots will start up and run your package tests in a "Test" stage.
- After the Test stage completes, a single bot will run a new "Documentation" stage, which
  will build the documentation.
- If the documentation is built successfully, the bot will attempt to push the generated
  HTML pages back to GitHub.

Note that the hosted documentation does not update when you make pull requests; you see
updates only when you merge to `master` or push new tags.

The following sections outline how to enable this for your own package.


## SSH Deploy Keys

Deploy keys provide push access to a *single* repository, to allow secure deployment of
generated documentation from Travis to GitHub. The SSH keys can be generated with the
`Travis.genkeys` from the [DocumenterTools](https://github.com/JuliaDocs/DocumenterTools.jl)
package.

!!! note

    You will need several command line programs (`which`, `git` and `ssh-keygen`) to be
    installed for the following steps to work. If DocumenterTools fails, please see the the
    [SSH Deploy Keys Walkthrough](@ref) section for instruction on how to generate the keys
    manually (including in Windows).


Install and load DocumenterTools with

```
pkg> add DocumenterTools
```
```julia-repl
julia> using DocumenterTools
```

Then call the [`Travis.genkeys`](@ref) function as follows:

```julia-repl
julia> using MyPackage
julia> Travis.genkeys(user="MyUser", repo="git@github.com:MyUser/MyPackage.jl.git")
```

where `MyPackage` is the name of the package you would like to create deploy keys for and `MyUser` is your GitHub username. Note that the keyword arguments are optional and can be omitted.

If the package is checked out in development mode with `] dev MyPackage`, you can also use `Travis.genkeys` as follows:

```julia-repl
julia> using MyPackage
julia> Travis.genkeys(MyPackage)
```

where `MyPackage` is the package you would like to create deploy keys for. The output will look similar to the text below:

```
INFO: add the public key below to https://github.com/USER/REPO/settings/keys
      with read/write access:

[SSH PUBLIC KEY HERE]

INFO: add a secure environment variable named 'DOCUMENTER_KEY' to
      https://travis-ci.com/USER/REPO/settings with value:

[LONG BASE64 ENCODED PRIVATE KEY]
```

Follow the instructions that are printed out, namely:

 1. Add the public ssh key to your settings page for the GitHub repository that you are
    setting up by following the `.../settings/key` link provided. Click on **`Add deploy
    key`**, enter the name **`documenter`** as the title, and copy the public key into the
    **`Key`** field. Check **`Allow write access`** to allow Documenter to commit the
    generated documentation to the repo.

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

!!! note

    There are more explicit instructions for adding the keys to GitHub and Travis in the
    [SSH Deploy Keys Walkthrough](@ref) section of the manual.

## `.travis.yml` Configuration

To tell Travis that we want a new build stage we can add the following to the `.travis.yml`
file:

```yaml
jobs:
  include:
    - stage: "Documentation"
      julia: 1.0
      os: linux
      script:
        - julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd()));
                                               Pkg.instantiate()'
        - julia --project=docs/ docs/make.jl
      after_success: skip
```

where the `julia:` and `os:` entries decide the worker from which the docs are built and
deployed. In the example above we will thus build and deploy the documentation from a linux
worker running Julia 1.0. For more information on how to setup a build stage, see the Travis
manual for [Build Stages](https://docs.travis-ci.com/user/build-stages).

The three lines in the `script:` section do the following:

 1. Instantiate the doc-building environment (i.e. `docs/Project.toml`, see below).
 2. Install your package in the doc-build environment.
 3. Run the docs/make.jl script, which builds and deploys the documentation.

!!! note
    If your package has a build script you should call
    `Pkg.build("PackageName")` after the call to `Pkg.develop` to make
    sure the package is built properly.

The doc-build environment `docs/Project.toml` includes Documenter and other doc-build
dependencies your package might have. If Documenter is the only dependency, then the
`Project.toml` should include the following:

````@eval
import Documenter, Markdown
m = match(r"^version = \"(\d+.\d+.\d+)(-DEV)?\"$"m,
    read(joinpath(dirname(dirname(pathof(Documenter))), "Project.toml"), String))
v = VersionNumber(m.captures[1])
Markdown.parse("""
```toml
[deps]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"

[compat]
Documenter = "$(v.major).$(v.minor)"
```
""")
````

Note that it is recommended that you have a `[compat]` section, like the one above, in your
`Project.toml` file, which would restrict Documenter's version that gets installed when the
build runs. This is to make sure that your builds do not start failing suddenly due to a new
major release of Documenter, which may include breaking changes. However, it also means that
you will not get updates to Documenter automatically, and hence need to upgrade Documenter's
major version yourself.


## The `deploydocs` Function

At the moment your `docs/make.jl` file probably only contains

```julia
using Documenter, PACKAGE_NAME

makedocs()
```

We'll need to add an additional function call to this file after [`makedocs`](@ref) which
would perform the deployment of the docs to the `gh-pages` branch.
Add the following at the end of the file:

```julia
deploydocs(
    repo = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
)
```

where `USER_NAME` and `PACKAGE_NAME` must be set to the appropriate names.
Note that `repo` should not specify any protocol, i.e. it should not begin with `https://`
or `git@`.

See the [`deploydocs`](@ref) function documentation for more details.



## `.gitignore`

Add the following to your package's `.gitignore` file

```
docs/build/
```

These are needed to avoid committing generated content to your repository.

## `gh-pages` Branch

By default, Documenter pushes documentation to the `gh-pages` branch. If the branch does not
exist it will be created automatically by [`deploydocs`](@ref). If it does exist then
Documenter simply adds an additional commit with the built documentation. You should be
aware that Documenter may overwrite existing content without warning.

If you wish to create the `gh-pages` branch manually that can be done following
[these instructions](https://coderwall.com/p/0n3soa/create-a-disconnected-git-branch).

## Documentation Versions

The documentation is deployed as follows:

- Documentation built for a tag `vX.Y.Z` will be stored in a folder `vX.Y.Z`.

- Documentation built from the `devbranch` branch (`master` by default) is stored a folder
  determined by the `devurl` keyword to [`deploydocs`](@ref) (`dev` by default).

Which versions that will show up in the version selector is determined by the
`versions` argument to [`deploydocs`](@ref).

Unless a custom domain is being used, the pages are found at:

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/vX.Y.Z
https://USER_NAME.github.io/PACKAGE_NAME.jl/dev
```

By default Documenter will create a link called `stable` that points to the latest release

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/stable
```

It is recommended to use this link, rather then the versioned links, since it will be updated
with new releases.

Once your documentation has been pushed to the `gh-pages` branch you should add links to
your `README.md` pointing to the `stable` (and perhaps `dev`) documentation URLs. It is common
practice to make use of "badges" similar to those used for Travis and AppVeyor build
statuses or code coverage. Adding the following to your package `README.md` should be all
that is necessary:

```markdown
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://USER_NAME.github.io/PACKAGE_NAME.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://USER_NAME.github.io/PACKAGE_NAME.jl/dev)
```

`PACKAGE_NAME` and `USER_NAME` should be replaced with their appropriate values. The colour
and text of the image can be changed by altering `docs-stable-blue` as described on
[shields.io](https://shields.io), though it is recommended that package authors follow this
standard to make it easier for potential users to find documentation links across multiple
package README files.

---

**Final Remarks**

That should be all that is needed to enable automatic documentation building. Pushing new
commits to your `master` branch should trigger doc builds. **Note that other branches do not
trigger these builds and neither do pull requests by potential contributors.**

If you would like to see a more complete example of how this process is setup then take a
look at this package's repository for some inspiration.
