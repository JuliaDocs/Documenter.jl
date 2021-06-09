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
    [Travis](https://travis-ci.com/) accounts setup. If not then go set those up first and
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

Note that the hosted documentation does not update when you make pull requests; you see
updates only when you merge to `master` or push new tags.

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
      julia: 1.6
      os: linux
      script:
        - julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd()));
                                               Pkg.instantiate()'
        - julia --project=docs/ docs/make.jl
      after_success: skip
```

where the `julia:` and `os:` entries decide the worker from which the docs are built and
deployed. In the example above we will thus build and deploy the documentation from a linux
worker running Julia 1.6. For more information on how to setup a build stage, see the Travis
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
    setting up by following the `.../settings/key` link provided. Click on **`Add deploy
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
          version: '1.6'
      - name: Install dependencies
        run: julia --project=docs/ -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
      - name: Build and deploy
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} # If authenticating with GitHub Actions token
          DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }} # If authenticating with SSH deploy key
        run: julia --project=docs/ docs/make.jl
```

which will install Julia, checkout the correct commit of your repository, and run the
build of the documentation. The `julia-version:`, `julia-arch:` and `os:` entries decide
the environment from which the docs are built and deployed. In the example above we will
thus build and deploy the documentation from a ubuntu worker running Julia 1.6. For more
information on how to setup a GitHub workflow see the manual:
[Learn GitHub Actions](https://docs.github.com/en/actions/learn-github-actions).

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
      schedule:
        - cron: 0 0 * * *
    jobs:
      TagBot:
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
(`GITHUB_TOKEN`)](https://docs.github.com/en/actions/reference/authentication-in-a-workflow). This is done by adding

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
[Encrypted secrets](https://docs.github.com/en/actions/reference/encrypted-secrets)
for more information.

### Add code coverage from documentation builds

If you want code run during the documentation deployment to be covered by Codecov,
you can edit the end of the docs part of your workflow configuration file so that
`docs/make.jl` is run with the `--code-coverage=user` flag and the coverage reports
are uploaded to Codecov:

```yaml
      - run: julia --project=docs/ --code-coverage=user docs/make.jl
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          DOCUMENTER_KEY: ${{ secrets.DOCUMENTER_KEY }}
      - uses: julia-actions/julia-processcoverage@v1
      - uses: codecov/codecov-action@v1
```

## `docs/Project.toml`

The doc-build environment `docs/Project.toml` includes Documenter and other doc-build
dependencies your package might have. If Documenter is the only dependency, then the
`Project.toml` should include the following:

````@eval
import Documenter, Markdown
m = match(r"^version = \"(\d+.\d+.\d+)(-DEV)?(\+.+)?\"$"m,
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

You also need to make sure that you have "gh-pages branch" selected as
[the source of the GitHub Pages site in your GitHub repository
settings](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site),
so that GitHub would actually serve the contents as a website.

**Cleaning up `gh-pages`.**
Note that the `gh-pages` branch can become very large, especially when `push_preview` is
enabled to build documentation for each pull request. To clean up the branch and remove
stale documentation previews, a GitHub Actions workflow like the following can be used.

```yaml
name: Doc Preview Cleanup

on:
  pull_request:
    types: [closed]

jobs:
  doc-preview-cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout gh-pages branch
        uses: actions/checkout@v2
        with:
          ref: gh-pages
      - name: Delete preview and history + push changes
        run: |
            if [ -d "previews/PR$PRNUM" ]; then
              git config user.name "Documenter.jl"
              git config user.email "documenter@juliadocs.github.io"
              git rm -rf "previews/PR$PRNUM"
              git commit -m "delete preview"
              git branch gh-pages-new $(echo "delete history" | git commit-tree HEAD^{tree})
              git push --force origin gh-pages-new:gh-pages
            fi
        env:
            PRNUM: ${{ github.event.number }}
```

_This workflow was taken from [CliMA/TimeMachine.jl](https://github.com/CliMA/TimeMachine.jl/blob/4d951f814b5b25cd2d13fd7a9f9878e75d0089d1/.github/workflows/DocCleanup.yml) (Apache License 2.0)._

## Documentation Versions

The documentation is deployed as follows:

- Documentation built for a tag `vX.Y.Z` will be stored in a folder `vX.Y.Z`.

- Documentation built from the `devbranch` branch (`master` by default) is stored in a folder
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

It is recommended to use this link, rather than the versioned links, since it will be updated
with new releases.

!!! info "Fixing broken release deployments"

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
```
