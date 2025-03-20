# Hosting Documentation

After going through the [Package Guide](@ref) and [Doctests](@ref) page you will need to
host the generated documentation somewhere for potential users to read. This guide will
describe how to set up automatic updates for your package docs using either the Travis CI
build service or GitHub Actions together with GitHub Pages for hosting the generated
HTML files. This is the same approach used by this package to host its own docs --
the docs you're currently reading.

!!! note

    Following this guide should be the *final* step you take after you are comfortable with
    the syntax and build process used by `Documenter.jl`. It is recommended that you only
    proceed with the steps outlined here once you have successfully managed to build your
    documentation locally with Documenter.

    This guide assumes that you already have [GitHub](https://github.com/) and
    [Travis](https://www.travis-ci.com/) accounts setup. If not then go set those up first and
    then return here.

    It is possible to deploy from other systems than Travis CI or GitHub Actions,
    see the section on [Deployment systems](@ref).


## Overview

Once set up correctly, the following will happen each time you push new updates to your
package repository:

- Buildbots will start up and run your package tests in a "Test" stage.
- After the Test stage completes, a single bot will run a new "Documentation" stage, which
  will build the documentation.
- If the documentation is built successfully, the bot will attempt to push the generated
  HTML pages back to GitHub.

Note that the hosted documentation does not update when you (or other contributors)
make pull requests; you see updates only when you merge to the trunk branch (typically,
`master` or `main`) or push new tags.

In the upcoming sections we describe how to configure the build service to run
the documentation build stage. In general it is easiest to choose the same
service as the one testing your package. If you don't explicitly select
the service with the `deploy_config` keyword argument to `deploydocs`
Documenter will try to automatically detect which system is running and use that.

## Travis CI

To tell Travis that we want a new build stage, we can add the following to an existing `.travis.yml`
file. Note that the snippet below will not work by itself and must be accompanied by a complete Travis file.

```yaml
jobs:
  include:
    - stage: "Documentation"
      julia: 1
      os: linux
      script:
        - julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd()));
                                               Pkg.instantiate()'
        - julia --project=docs/ docs/make.jl
      after_success: skip
```

where the `julia:` and `os:` entries decide the worker from which the docs are built and
deployed. In the example above we will thus build and deploy the documentation from a linux
worker running Julia 1 (the latest stable version). For more information on how to setup a build stage, see the Travis
manual for [Build Stages](https://docs.travis-ci.com/user/build-stages).

The three lines in the `script:` section do the following:

 1. Instantiate the doc-building environment (i.e. `docs/Project.toml`, see below).
 2. Install your package in the doc-build environment.
 3. Run the docs/make.jl script, which builds and deploys the documentation.

!!! note
    If your package has a build script you should call
    `Pkg.build("PackageName")` after the call to `Pkg.develop` to make
    sure the package is built properly.

!!! note "matrix: section in .travis.yml"

    Travis CI used to use `matrix:` as the section to configure to build matrix in the config
    file. This now appears to be a deprecated alias for `jobs:`. If you use both `matrix:` and
    `jobs:` in your configuration, `matrix:` overrides the settings under `jobs:`.

    If your `.travis.yml` file still uses `matrix:`, it should be replaced with a a single
    `jobs:` section.

### [Authentication: SSH Deploy Keys](@id travis-ssh)

In order to push the generated documentation from Travis you need to add deploy keys.
Deploy keys provide push access to a *single* repository, to allow secure deployment of
generated documentation from the builder to GitHub. The SSH keys can be generated with
`DocumenterTools.genkeys` from the [DocumenterTools](https://github.com/JuliaDocs/DocumenterTools.jl) package.

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

Then call the [`DocumenterTools.genkeys`](@ref) function as follows:

```julia-repl
julia> using DocumenterTools
julia> DocumenterTools.genkeys(user="MyUser", repo="MyPackage.jl")
```

where `MyPackage` is the name of the package you would like to create deploy keys for and
`MyUser` is your GitHub username. Note that the keyword arguments are optional and can be
omitted.

If the package is checked out in development mode with `] dev MyPackage`, you can also use
`DocumenterTools.genkeys` as follows:

```julia-repl
julia> using MyPackage
julia> DocumenterTools.genkeys(MyPackage)
```

where `MyPackage` is the package you would like to create deploy keys for. The output will
look similar to the text below:

```
[ Info: add the public key below to https://github.com/USER/REPO/settings/keys
      with read/write access:

[SSH PUBLIC KEY HERE]

[ Info: add a secure environment variable named 'DOCUMENTER_KEY' to
  https://travis-ci.com/USER/REPO/settings with value:

[LONG BASE64 ENCODED PRIVATE KEY]
```

Follow the instructions that are printed out, namely:

 1. Add the public ssh key to your settings page for the GitHub repository that you are
    setting up by following the `.../settings/keys` link provided. Click on **`Add deploy
    key`**, enter the name **`documenter`** as the title, and copy the public key into the
    **`Key`** field. Check **`Allow write access`** to allow Documenter to commit the
    generated documentation to the repo.

 2. Next add the long private key to the Travis settings page using the provided link.
    Again note that you should include **no whitespace** when copying the key. In the **`Environment
    Variables`** section add a key with the name `DOCUMENTER_KEY` and the value that was printed
    out. **Do not** set the variable to be displayed in the build log. Then click **`Add`**.

    !!! warning "Security warning"

        To reiterate: make sure that this key is hidden. In particular, in the Travis CI settings
        the "Display value in build log" option should be **OFF** for
        the variable, so that it does not get printed when the tests run. This
        base64-encoded string contains the *unencrypted* private key that gives full write
        access to your repository, so it must be kept safe.  Also, make sure that you never
        expose this variable in your tests, nor merge any code that does. You can read more
        about Travis environment variables in [Travis User Documentation](https://docs.travis-ci.com/user/environment-variables/#Defining-Variables-in-Repository-Settings).

!!! note

    There are more explicit instructions for adding the keys to Travis in the
    [SSH Deploy Keys Walkthrough](@ref) section of the manual.


## GitHub Actions

To run the documentation build from GitHub Actions, create a new workflow
configuration file called `.github/workflows/documentation.yml` with the
following contents:
```yaml
name: Documentation

on:
  push:
    branches:
      - master # update to match your development branch (master, main, dev, trunk, ...)
    tags: '*'
  pull_request:

jobs:
  build:
    # These permissions are needed to:
    # - Deploy the documentation: https://documenter.juliadocs.org/stable/man/hosting/#Permissions
    # - Delete old caches: https://github.com/julia-actions/cache#usage
    permissions:
      actions: write
      contents: write
      pull-requests: read
      statuses: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: '1'
      - uses: julia-actions/cache@v2
      - name: Install dependencies
        shell: julia --color=yes --project=docs {0}
        run: |
          using Pkg
          Pkg.develop(PackageSpec(path=pwd()))
          Pkg.instantiate()
      - name: Build and deploy
        run: julia --color=yes --project=docs docs/make.jl
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} # If authenticating with GitHub Actions token
          DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }} # If authenticating with SSH deploy key
```

This will install Julia, checkout the correct commit of your repository, and run the
build of the documentation. The `julia-version:`, `julia-arch:` and `os:` entries decide
the environment from which the docs are built and deployed. The example above builds and deploys
the documentation from an Ubuntu worker running Julia 1.

!!! tip
    The example above is a basic workflow that should suit most projects. For more information on
    how to further customize your action, check out the [GitHub Actions manual](https://docs.github.com/en/actions).

The commands in the lines in the `run:` section do the same as for Travis,
see the previous section.

!!! warning "TagBot & tagged versions"

    In order to deploy documentation for **tagged versions**, the GitHub Actions workflow
    needs to be triggered by the tag. However, by default, when the [Julia TagBot](https://github.com/marketplace/actions/julia-tagbot)
    uses just the `GITHUB_TOKEN` for authentication, it does not have the permission to trigger
    any further workflows jobs, and so the documentation CI job never runs for the tag.

    To work around that, TagBot should be [configured to use `DOCUMENTER_KEY`](https://github.com/marketplace/actions/julia-tagbot#ssh-deploy-keys)
    for authentication, by adding `ssh: ${{ secrets.DOCUMENTER_KEY }}` to the `with` section.
    A complete TagBot workflow file could look as follows:

    ```yml
    name: TagBot
    on:
      issue_comment:
        types:
          - created
      workflow_dispatch:
    jobs:
      TagBot:
        if: github.event_name == 'workflow_dispatch' || github.actor == 'JuliaTagBot'
        runs-on: ubuntu-latest
        steps:
          - uses: JuliaRegistries/TagBot@v1
            with:
              token: ${{ secrets.GITHUB_TOKEN }}
              ssh: ${{ secrets.DOCUMENTER_KEY }}
    ```

### Authentication: `GITHUB_TOKEN`

When running from GitHub Actions it is possible to authenticate using
[the GitHub Actions authentication token
(`GITHUB_TOKEN`)](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication). This is done by adding

```yaml
GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

to the configuration file, as showed in the [previous section](@ref GitHub-Actions).

!!! note
    You can only use `GITHUB_TOKEN` for authentication if the target repository
    of the deployment is the same as the current repository. In order to push
    elsewhere you should instead use a SSH deploy key.

### Authentication: SSH Deploy Keys

It is also possible to authenticate using a SSH deploy key, just as described in
the [SSH Deploy Keys section for Travis CI](@ref travis-ssh). You can generate the
key in the same way, and then set the encoded key as a secret environment variable
in your repository settings. You also need to make the key available for the doc
building workflow by adding

```yaml
DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }}
```

to the configuration file, as showed in the [previous section](@ref GitHub-Actions).
See GitHub's manual for
[Encrypted secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)
for more information.

### Permissions

The following [GitHub Actions job or workflow permissions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token) are required to successfully use [`deploydocs`](#the-deploydocs-function):

```yaml
permissions:
  contents: write  # Required when authenticating with `GITHUB_TOKEN`, not needed when authenticating with SSH deploy keys
  pull-requests: read  # Required when using `push_preview=true`
  statuses: write  # Optional, used to report documentation build statuses
```

### Add code coverage from documentation builds

If you want code run during the documentation deployment to be covered by Codecov,
you can edit the end of the docs part of your workflow configuration file so that
`docs/make.jl` is run with the `--code-coverage=user` flag and the coverage reports
are uploaded to Codecov:

```yaml
      - run: julia --project=docs --code-coverage=user docs/make.jl
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }}
      - uses: julia-actions/julia-processcoverage@v1
      - uses: codecov/codecov-action@v5
```

## `docs/Project.toml`

The doc-build environment `docs/Project.toml` includes Documenter and other doc-build
dependencies your package might have. If Documenter is the only dependency, then the
`Project.toml` should include the following:

````@eval
import Documenter, Markdown
v = Documenter.DOCUMENTER_VERSION
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

If you wish to create the `gh-pages` branch manually, that can be done [creating an "orphan" branch, with the `git checkout --orphan` option](https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt---orphanltnew-branchgt).

You also need to make sure that you have `gh-pages branch` and `/ (root)` selected as
[the source of the GitHub Pages site in your GitHub repository
settings](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site),
so that GitHub would actually serve the contents as a website.

### Cleaning up `gh-pages`

The `gh-pages` branch can become very large, especially when `push_preview` is
enabled to build documentation for each pull request. To clean up the branch and remove
stale documentation previews, a GitHub Actions workflow like the following can be used.

```yaml
name: Doc Preview Cleanup

on:
  pull_request:
    types: [closed]

# Ensure that only one "Doc Preview Cleanup" workflow is force pushing at a time
concurrency:
  group: doc-preview-cleanup
  cancel-in-progress: false

jobs:
  doc-preview-cleanup:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout gh-pages branch
        uses: actions/checkout@v4
        with:
          ref: gh-pages
      - name: Delete preview and history + push changes
        run: |
          if [ -d "${preview_dir}" ]; then
              git config user.name "Documenter.jl"
              git config user.email "documenter@juliadocs.github.io"
              git rm -rf "${preview_dir}"
              git commit -m "delete preview"
              git branch gh-pages-new "$(echo "delete history" | git commit-tree "HEAD^{tree}")"
              git push --force origin gh-pages-new:gh-pages
          fi
        env:
          preview_dir: previews/PR${{ github.event.number }}
```

_This workflow was based on [CliMA/ClimaTimeSteppers.jl](https://github.com/CliMA/ClimaTimeSteppers.jl/blob/0660ace688b4f4b8a86d3c459ab62ccf01d7ef31/.github/workflows/DocCleanup.yml) (Apache License 2.0)._

The `permissions:` line above is described in the
[GitHub Docs](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token#setting-the-github_token-permissions-for-a-specific-job);
an alternative is to give GitHub workflows write permissions under the repo settings, e.g.,
`https://github.com/<USER>/<REPO>.jl/settings/actions`.

## Woodpecker CI

To run a documentation build from Woodpecker CI, one should create an access token
from their forge of choice: GitHub, GitLab, or Codeberg (or any Gitea instance).
This access token should be added to Woodpecker CI as a secret named as
`project_access_token`. The case does not matter since this will be passed as
uppercase environment variables to your pipeline. Next, create a new pipeline
configuration file called `.woodpecker.yml` with the following contents:

- Woodpecker 0.15.x and pre-1.0.0

  ```yaml
  pipeline:
      docs:
      when:
          branch: main  # update to match your development branch
      image: julia
      commands:
          - julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
          - julia --project=docs/ docs/make.jl
      secrets: [ project_access_token ]  # access token is a secret

  ```

- Woodpecker 1.0.x and onwards

  ```yaml
  steps:
      docs:
      when:
          branch: main  # update to match your development branch
      image: julia
      commands:
          - julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
          - julia --project=docs/ docs/make.jl
      secrets: [ project_access_token ]  # access token is a secret

  ```

This will pull an image of julia from docker and run the following commands from
`commands:` which instantiates the project for development and then runs the `make.jl`
file and builds and deploys the documentation to a branch which defaults to `pages`
which you can modify to something else e.g. GitHub → gh-pages, Codeberg → pages.

!!! tip
	The example above is a basic pipeline that suits most projects. Further information
	on how to customize your pipelines can be found in the official woodpecker
	documentation: [Woodpecker CI](https://woodpecker-ci.org/docs/intro).

## Documentation Versions

!!! note
    This section describes the default mode of deployment, which is by version.
    See the following section on [Deploying without the versioning scheme](@ref)
    if you want to deploy directly to the "root".

By default the documentation is deployed as follows:

- Documentation built for a tag `<tag_prefix>vX.Y.Z` will be stored in a folder `vX.Y.Z`,
  determined by the `tag_prefix` keyword to [`deploydocs`](@ref)
  (`""` by default).

- Documentation built from the `devbranch` branch (`master` by default) is stored in a folder
  determined by the `devurl` keyword to [`deploydocs`](@ref) (`dev` by default).

Which versions will show up in the version selector is determined by the
`versions` argument to [`deploydocs`](@ref). For examples of non-default `tag_prefix` usage, see [Deploying from a monorepo](@ref).

Unless a custom domain is being used, the pages are found at:

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/vX.Y.Z
https://USER_NAME.github.io/PACKAGE_NAME.jl/dev
```

!!! tip
    If you need Documenter to maintain [a `CNAME` file](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) for you can use the `cname` argument of [`deploydocs`](@ref) to specify the domain.

By default Documenter will create a link called `stable` that points to the latest release

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/stable
```

It is recommended to use this link, rather than the versioned links, since it will be updated
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

### Fixing broken release deployments

It can happen that, for one reason or another, the documentation for a tagged version of
your package fails to deploy and a fix would require changes to the source code (e.g. a
misconfigured `make.jl`). However, as registered tags should not be changed, you can not
simply update the original tag (e.g. `v1.2.3`) with the fix.

In this situation, you can manually create and push a tag for the commit with the fix
that has the same version number, but also some build metadata (e.g. `v1.2.3+doc1`). For
Git, this is a completely different tag, so it won't interfere with anything. But when
Documenter runs on this tag, it will ignore the build metadata and deploy the docs as if
they were for version `v1.2.3`.

Note that, as with normal tag builds, you need to make sure that your CI that runs
Documenter is configured to run on such tags (e.g. that the regex constraining the
branches the CI runs on is broad enough etc).

### Deploying without the versioning scheme

Documenter supports deployment directly to the website root ignoring any version
subfolders as described in the previous section. This can be useful if you use
Documenter for something that is not a versioned project, for example.
To do this, pass `versions = nothing` to the [`deploydocs`](@ref) function.
Now the pages should be found directly at

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/
```

Preview builds are still deployed to the `previews` subfolder.

!!! note
    The landing page for the [JuliaDocs GitHub organization](https://juliadocs.org/)
    ([source repository](https://github.com/JuliaDocs/juliadocs.github.io)) is one example
    where this functionality is used.

### Out-of-repo deployment

Sometimes the `gh-pages` branch can become really large, either just due to a large number of commits over time, or due figures and other large artifacts.
In those cases, it can be useful to deploy the docs in the `gh-pages` of a separate repository.
The following steps can be used to deploy the documentation of a "source"
repository on a "target" repo:

1. Run `DocumenterTools.genkeys()` to generate a pair of keys
2. Add the **deploy key** to the **"target"** repository
3. Add the `DOCUMENTER_KEY` **secret** to the **"source"** repository (that runs the documentation workflow)
4. Adapt `docs/make.jl` to deploy on "target" repository:

```julia
# url of target repo
repo = "github.com/TargetRepoOrg/TargetRepo.git"

# You have to override the corresponding environment variable that
# deplodocs uses to determine if it is deploying to the correct repository.
# For GitHub, it's the GITHUB_REPOSITORY variable:
withenv("GITHUB_REPOSITORY" => repo) do
  deploydocs(repo=repo)
end
```

## Deploying from a monorepo

Documenter.jl supports building documentation for a package that lives in a monorepo, e.g., in a repository that contains multiple packages (including one potentially top level)

Here's one example of setting up documentation for a repository that has the following structure: one top level package and two subpackages PackageA.jl and PackageB.jl:
```
.
├── README.md
├── docs
|   ├── make.jl
│   └── Project.toml
├── src/...
├── PackageA.jl
│   ├── docs
|   │   ├── make.jl
|   │   └── Project.toml
│   └── src/...
└── PackageB.jl
    ├── docs
    │   ├── make.jl
    │   └── Project.toml
    └── src/...
```

The three respective `make.jl` scripts should contain [`deploydocs`](@ref) settings that look something like

```julia
# In ./docs/make.jl
deploydocs(; repo = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
            # ...any additional kwargs
            )

# In ./PackageA.jl/docs/make.jl
deploydocs(; repo = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
             dirname="PackageA",
             tag_prefix="PackageA-",
             # ...any additional kwargs
             )

# In ./PackageB.jl/docs/make.jl
deploydocs(; repo = "github.com/USER_NAME/PACKAGE_NAME.jl.git",
             dirname="PackageB",
             tag_prefix="PackageB-",
             # ...any additional kwargs
             )
```

To build separate docs for each package, create three **separate** buildbot configurations, one for each package. Depending on the service used, the section that calls each `make.jl` script will need to be configured appropriately, e.g.,
```
# In the configuration file that builds docs for the top level package
run: julia --project=docs/ docs/make.jl

# In the configuration file that builds docs for PackageA.jl
run: julia --project=PackageA.jl/docs/ PackageA.jl/docs/make.jl

# In the configuration file that builds docs for PackageB.jl
run: julia --project=PackageB.jl/docs/ PackageB.jl/docs/make.jl
```

Releases of each subpackage should be tagged with that same prefix, namely `v0.3.2` (for the top-level package), `PackageA-v0.1.2`, and `PackageB-v3.2+extra_build_tags`. which will then trigger versioned documentation deployments. Similarly to [Documentation Versions](@ref), unless a custom domain is used these three separate sets of pages will be found at:

```
https://USER_NAME.github.io/PACKAGE_NAME.jl/vX.Y.Z
https://USER_NAME.github.io/PACKAGE_NAME.jl/dev
https://USER_NAME.github.io/PACKAGE_NAME.jl/stable  # Links to most recent top level version

https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageA/vX.Y.Z
https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageA/dev
https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageA/stable  # Links to most recent PackageA version

https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageB/vX.Y.Z
https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageB/dev
https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageB/stable  # Links to most recent PackageB version
```

While they won't automatically reference one another, such referencing can be added manually (e.g. by linking to `https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageA/stable` from the docs built for PackageB).

!!! warning
    When building multiple subpackages in the same repo, unique `dirname`s must be specified in each package's `deploydocs`; otherwise, only the most recently built package for a given version over the entire monorepo will be present at `https://USER_NAME.github.io/PACKAGE_NAME.jl/PackageB/vX.Y.Z`, and the rest of the subpackages' documentation will be unavailable.

## Deployment systems

It is possible to customize Documenter to use other systems then the ones described in
the sections above. This is done by passing a configuration
(a [`DeployConfig`](@ref Documenter.DeployConfig)) to `deploydocs` by the `deploy_config`
keyword argument. Documenter supports [`Travis`](@ref Documenter.Travis),
[`GitHubActions`](@ref Documenter.GitHubActions), [`GitLab`](@ref Documenter.GitLab), and
[`Buildkite`](@ref Documenter.Buildkite) natively, but it is easy to define your own by
following the simple interface described below.

```@docs
Documenter.DeployConfig
Documenter.deploy_folder
Documenter.DeployDecision
Documenter.authentication_method
Documenter.authenticated_repo_url
Documenter.documenter_key
Documenter.documenter_key_previews
Documenter.Travis
Documenter.GitHubActions
Documenter.GitLab
Documenter.Buildkite
Documenter.Woodpecker
```
