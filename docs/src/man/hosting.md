# Hosting Documentation

After going through the [Package Guide](@ref) and [Doctests](@ref) page you will need to
host the generated documentation somewhere for potential users to read. This guide will
describe how to setup automatic updates for your package docs using
GitHub Actions together with and GitHub Pages for hosting the generated
HTML files. This is the same approach used by this package to host its own docs --
the docs you're currently reading.

!!! note

    Following this guide should be the *final* step you take after you are comfortable with
    the syntax and build process used by `Documenter.jl`. It is recommended that you only
    proceed with the steps outlined here once you have successfully managed to build your
    documentation locally with Documenter.

    This guide assumes that you already have a [GitHub](https://github.com/)
    account setup. If not then go set those up first and
    then return here.

    It is possible to deploy from other systems than GitHub Actions,
    see the section on [Deployment systems](@ref).


## Overview

Once set up correctly, the following will happen each time you push new updates to your
package repository:

- Buildbots will start up and run your package tests in a "Test" stage.
- After the Test stage completes, a single bot will run a new "Documentation" stage, which
  will build the documentation.
- If the documentation is built successfully, the bot will attempt to push the generated
  HTML pages back to GitHub.

Note that the hosted documentation does not update when you make pull requests; you see
updates only when you merge to `master` or push new tags.

In the upcoming sections we describe how to configure the build service to run
the documentation build stage. In general it is easiest to choose the same
service as the one testing your package. If you don't explicitly select
the service with the `deploy_config` keyword argument to `deploydocs`
Documenter will try to automatically detect which system is running and use that.

### [Authentication: SSH Deploy Keys]

In order to push the generated documentation from GitHub actions you need to add deploy keys.
Deploy keys provide push access to a *single* repository, to allow secure deployment of
generated documentation from the builder to GitHub. The SSH keys can be generated and
submitted with `OnlinePackage.jl`. See the instructions for using that package
[here](https://bramtayl.github.io/OnlinePackage.jl/latest/).

## GitHub Actions

To run the documentation build from GitHub Actions you should add the following to your
workflow configuration file:

```yaml
name: Documentation

on:
  push:
    branches:
      - master
    tags: '*'
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: julia-actions/setup-julia@latest
        with:
          version: 1.3
      - uses: julia-actions/julia-docdeploy@releases/v1
        env:
          DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }}
```

which will install Julia, checkout the correct commit of your repository, and run the
build of the documentation. The `julia-version:`, `julia-arch:` and `os:` entries decide
the environment from which the docs are built and deployed. In the example above we will
thus build and deploy the documentation from a ubuntu worker running Julia 1.2. For more
information on how to setup a GitHub workflow see the manual for
[Configuring a workflow](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/configuring-a-workflow).

## `docs/Project.toml`

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

## Deployment systems

It is possible to customize Documenter to use other systems then the ones described in
the sections above. This is done by passing a configuration
(a [`DeployConfig`](@ref Documenter.DeployConfig)) to `deploydocs` by the `deploy_config`
keyword argument. Documenter natively supports [`Travis`](@ref Documenter.Travis) and
[`GitHubActions`](@ref Documenter.GitHubActions) natively, but it is easy to define
your own by following the simple interface described below.

```@docs
Documenter.DeployConfig
Documenter.deploy_folder
Documenter.authentication_method
Documenter.authenticated_repo_url
Documenter.documenter_key
Documenter.Travis
Documenter.GitHubActions
```
