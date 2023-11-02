# Checklists

The purpose of this page is to collate a series of checklists for commonly
performed changes to the source code of Documenter.

In each case, copy the checklist into the description of the pull request.

## Making a release

In preparation for a release, use the following checklist.

````
## Pre-release

 - [ ] Change the version number in `Project.toml`
        * If the release is breaking, increment MAJOR
        * If the release adds a new user-visible feature, increment MINOR
        * Otherwise (bug-fixes, documentation improvements), increment PATCH
 - [ ] Update `CHANGELOG.md`, following the existing style (in particular, make
       sure that the change log for this version has the correct version number
       and date).
 - [ ] Run `make changelog`, to make sure that all the issue references in
       `CHANGELOG.md` are up to date.
 - [ ] Check that the commit messages in this PR do not contain `[ci skip]`

## The release

 - [ ] After merging this pull request, tag the release. There are two options for this:

      1. [Comment `[at]JuliaRegistrator register` on the GitHub commit.](https://github.com/JuliaRegistries/Registrator.jl#via-the-github-app)
      2. Use [JuliaHub's package registration feature](https://help.juliahub.com/juliahub/stable/contribute/#registrator) to trigger the registration.   

   Either of those should automatically publish a new version to the Julia registry.
   Once registered, the `TagBot.yml` workflow should create a tag, and rebuild the
   documentation for this tag. These steps can take quite a bit of time (1
   hour or more), so don't be surprised if the new documentation takes a
   while to appear.
````
