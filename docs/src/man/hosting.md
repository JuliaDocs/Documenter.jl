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

- Travis buildbots startup and run your tests in a test stage;
- after the test stage a single bot will start a new "deploy docs" stage;
- if the building is successful the bot will try to push the generated
  docs back to GitHub.

Note that the hosted documentation does not update when you make pull
requests; you see updates only when you merge to `master` or push new tags.

The following sections outline how to enable this for your own package.

## SSH Deploy Keys

Deploy keys provide push access to a *single* repository, to allow secure deployment of generated documentation from Travis to GitHub.

!!! note

    You will need several command line programs installed for the following steps to work.
    They are `which`, `git`, and `ssh-keygen`. Make sure these are installed before you
    begin this section.

SSH keys can be generated with the `Travis.genkeys` from the `DocumenterTools` package.
Install and load it as

```
pkg> add DocumenterTools
```
```jlcon
julia> using DocumenterTools
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

To tell Travis that we want a new build stage we can add the following to the
`.travis.yml` file:

```yaml
jobs:
  include:
    - stage: "Documentation"
      julia: 1.0
      os: linux
      script:
        - julia --project=docs/ -e 'using Pkg; Pkg.instantiate();
                                    Pkg.add(PackageSpec(path=pwd()))'
        - julia --project=docs/ docs/make.jl
      after_success: skip
```

where the `julia:` and `os:` entries decide the worker from which the docs
are built and deployed. In the example above we will thus build and deploy
the documentation from a linux worker running Julia 1.0.
For more information on how to setup a build stage,
see the Travis manual for [Build Stages](https://docs.travis-ci.com/user/build-stages).

The three lines in the `script:` section does the following:
 1. Instantiate the doc-building environment (i.e. `docs/Project.toml`, see below).
 2. Install your package in the doc-build environment.
 3. Run the docs/make.jl script, which builds and deploys the documentation.

The doc-build environment `docs/Project.toml` includes Documenter
and other doc-build dependencies your package might have.
If Documenter is the only dependency, then the `Project.toml`
should include the following:
```toml
[deps]
Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"

[compat]
Documenter = "0.20"
```


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

```
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
