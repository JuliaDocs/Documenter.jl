# Implements deploydocs()

"""
    deploydocs(
        root = "<current-directory>",
        target = "build",
        dirname = "",
        repo = "<required>",
        branch = "gh-pages",
        deps = nothing | <Function>,
        make = nothing | <Function>,
        devbranch = nothing,
        devurl = "dev",
        versions = ["stable" => "v^", "v#.#", devurl => devurl],
        forcepush = false,
        deploy_config = auto_detect_deploy_system(),
        push_preview = false,
        repo_previews = repo,
        branch_previews = branch,
        tag_prefix = "",
    )

Copies the files generated by [`makedocs`](@ref) in `target` to the appropriate
(sub-)folder in `dirname` on the deployment `branch`, commits them, and pushes
to `repo`.

This function should be called from within a package's `docs/make.jl` file after
the call to [`makedocs`](@ref), like so

```julia
using Documenter, PACKAGE_NAME
makedocs(
    # options...
)
deploydocs(
    repo = "github.com/..."
)
```

When building the docs for a tag (i.e. a release) the documentation is deployed to
a directory with the tag name (i.e. `vX.Y.Z`) and to the `stable` directory.
Otherwise the docs are deployed to the directory determined by the `devurl` argument.

The deployment procedure consists of the following steps:

* Check out the `branch` of `repo` to a temporary location
* Remove the existing deployment (sub-)directory with `git rm -r`
* Copy the `target` (build) folder to the deployment directory
* Generate `index.html`, and `versions.js` in the `branch` root and
  `siteinfo.js` in the deployment directory
* Add all files on the deployment `branch` (`git add -A .`), commit them, and
  push the `repo`. Note that any `.gitignore` files in the `target` directory
  affect which files will be committed to `branch`.

# Required keyword arguments

**`repo`** is the remote repository where generated HTML content should be pushed to. Do not
specify any protocol - "https://" or "git@" should not be present. This keyword *must*
be set and will throw an error when left undefined. For example this package uses the
following `repo` value:

```julia
repo = "github.com/JuliaDocs/Documenter.jl.git"
```

# Optional keyword arguments

**`deploy_config`** determines configuration for the deployment.
If this is not specified Documenter will try to autodetect from the
currently running environment. See the manual section about
[Deployment systems](@ref).

**`root`** has the same purpose as the `root` keyword for [`makedocs`](@ref).

**`target`** is the directory, relative to `root`, where generated content that should be
deployed to `gh-pages` is written to. It should generally be the same as
[`makedocs`](@ref)'s `build` and defaults to `"build"`.

**`branch`** is the branch where the generated documentation is pushed. If the branch does
not exist, a new orphaned branch is created automatically. It defaults to `"gh-pages"`.

**`dirname`** is a subdirectory of `branch` that the docs should be added to. By default,
it is `""`, which will add the docs to the root directory.

**`devbranch`** is the branch that "tracks" the in-development version of the generated
documentation. By default Documenter tries to figure this out using `git`. Can be set
explicitly as a string (typically `"master"` or `"main"`).

**`devurl`** the folder that in-development version of the docs will be deployed.
Defaults to `"dev"`.

**`forcepush`** a boolean that specifies the behavior of the git-deployment.
The default (`forcepush = false`) is to push a new commit, but when
`forcepush = true` the changes will be combined with the previous commit and
force pushed, erasing the Git history on the deployment branch.

**`versions`** determines content and order of the resulting version selector in
the generated html. The following entries are valid in the `versions` vector:
 - `"v#"`: includes links to the latest documentation for each major release cycle
   (i.e. `v2.0`, `v1.1`).
 - `"v#.#"`: includes links to the latest documentation for each minor release cycle
   (i.e. `v2.0`, `v1.1`, `v1.0`, `v0.1`).
 - `"v#.#.#"`: includes links to all released versions.
 - `"v^"`: includes a link to the docs for the maximum version
   (i.e. a link `vX.Y` pointing to `vX.Y.Z` for highest `X`, `Y`, `Z`, respectively).
 - A pair, e.g. `"first" => "second"`, which will put `"first"` in the selector,
   and generate a url from which `"second"` can be accessed.
   The second argument can be `"v^"`, to point to the maximum version docs
   (as in e.g. `"stable" => "v^"`).
If `versions = nothing` documentation will be deployed directly to the "root", i.e.
not to a versioned subfolder. See the manual section on
[Deploying without the versioning scheme](@ref) for more details.

**`push_preview`** a boolean that specifies if preview documentation should be
deployed from pull requests or not. If your published documentation is hosted
at `"https://USER.github.io/PACKAGE.jl/stable`, by default the preview will be
hosted at `"https://USER.github.io/PACKAGE.jl/previews/PR##"`. This feature
works for pull requests with head branch in the same repository, i.e. not from
forks.

**`branch_previews`** is the branch to which pull request previews are deployed.
It defaults to the value of `branch`.

**`repo_previews`** is the remote repository to which pull request previews are
deployed. It defaults to the value of `repo`.

!!! note
    Pull requests made from forks will not have previews.
    Hosting previews requires access to the deploy key.
    Therefore, previews are available only for pull requests that were
    submitted directly from the main repository.
    On GitHub Actions, `GITHUB_TOKEN` must be present for previews to work, even if
    `DOCUMENTER_KEY` ise being used to deploy.

**`deps`** can be set to a function or a callable object and gets called during deployment,
and is usually used to install additional dependencies. By default, nothing gets executed.

**`make`** can be set to a function or a callable object and gets called during deployment,
and is usually used to specify additional build steps. By default, nothing gets executed.

**`tag_prefix`** can be set to allow prefixed version numbers to determine the version
number of a release. If `tag_prefix = ""` (the default), only version tags will trigger
deployment; with a non-empty `tag_prefix`, only version tags with that prefix will
trigger deployment. See manual sections on [Documentation Versions](@ref) and
[Deploying from a monorepo](@ref) for more details.

# Releases vs development branches

[`deploydocs`](@ref) will automatically figure out whether it is deploying the documentation
for a tagged release or just a development branch (usually, based on the environment
variables set by the CI system).

With versioned tags, [`deploydocs`](@ref) discards the build metadata (i.e. `+` and
everything that follows it) from the version number when determining the name of the
directory into which the documentation gets deployed, as well as the `tag_prefix`
(if present). Pre-release identifiers are preserved.

# See Also

The [Hosting Documentation](@ref) section of the manual provides a step-by-step guide to
using the [`deploydocs`](@ref) function to automatically generate docs and push them to
GitHub.
"""
function deploydocs(;
        root   = currentdir(),
        target = "build",
        dirname = "",

        repo   = error("no 'repo' keyword provided."),
        branch = "gh-pages",

        repo_previews   = repo,
        branch_previews = branch,

        deps   = nothing,
        make   = nothing,

        devbranch = nothing,
        devurl = "dev",
        versions = ["stable" => "v^", "v#.#", devurl => devurl],
        forcepush::Bool = false,
        deploy_config = auto_detect_deploy_system(),
        push_preview::Bool = false,
        tag_prefix = "",

        archive = nothing, # experimental and undocumented
    )

    # Try to figure out default branch (see #1443 and #1727)
    if devbranch === nothing
        devbranch = git_remote_head_branch("deploydocs(devbranch = ...)", root)
    end

    if !isnothing(archive)
        # If archive is a relative path, we'll make it relative to the make.jl
        # directory (e.g. docs/)
        archive = joinpath(root, archive)
        ispath(archive) && error("Output archive exists: $archive")
    end

    deploy_decision = deploy_folder(deploy_config;
                                    branch=branch,
                                    branch_previews=branch_previews,
                                    devbranch=devbranch,
                                    devurl=devurl,
                                    push_preview=push_preview,
                                    repo=repo,
                                    repo_previews=repo_previews,
                                    tag_prefix)
    if deploy_decision.all_ok
        deploy_branch = deploy_decision.branch
        deploy_repo = deploy_decision.repo
        deploy_subfolder = deploy_decision.subfolder
        deploy_is_preview = deploy_decision.is_preview

        # Non-versioned docs: deploy to root
        if versions === nothing && !deploy_is_preview
            deploy_subfolder = nothing
        end

        # Install dependencies when applicable.
        if deps !== nothing
            @debug "installing dependencies."
            deps()
        end
        # Change to the root directory and try to deploy the docs.
        cd(root) do
            # Find the commit sha.
            # We'll make sure we run the git commands in the source directory (root), in case
            # the working directory has been changed (e.g. if the makedocs' build argument is
            # outside root).
            sha = try
                readchomp(`$(git()) rev-parse --short HEAD`)
            catch
                # git rev-parse will throw an error and return code 128 if it is not being
                # run in a git repository, which will make run/readchomp throw an exception.
                # We'll assume that if readchomp fails it is due to this and set the sha
                # variable accordingly.
                "(not-git-repo)"
            end

            @debug "setting up target directory."
            isdir(target) || mkpath(target)
            # Run extra build steps defined in `make` if required.
            if make !== nothing
                @debug "running extra build steps."
                make()
            end
            @debug "pushing new documentation to remote: '$deploy_repo:$deploy_branch'."
            mktempdir() do temp
                git_push(
                    root, temp, deploy_repo;
                    branch=deploy_branch, dirname=dirname, target=target,
                    sha=sha, deploy_config=deploy_config, subfolder=deploy_subfolder,
                    devurl=devurl, versions=versions, forcepush=forcepush,
                    is_preview=deploy_is_preview, archive=archive,
                )
            end
        end
    end
end

"""
    git_push(
        root, tmp, repo;
        branch="gh-pages", dirname="", target="site", sha="", devurl="dev",
        deploy_config, folder,
    )

Handles pushing changes to the remote documentation branch.
The documentation are placed in the folder specified by `subfolder`.
"""
function git_push(
        root, temp, repo;
        branch="gh-pages", dirname="", target="site", sha="", devurl="dev",
        versions, forcepush=false, deploy_config, subfolder,
        is_preview::Bool = false, archive,
    )
    dirname = isempty(dirname) ? temp : joinpath(temp, dirname)
    isdir(dirname) || mkpath(dirname)

    target_dir = abspath(target)

    if startswith(homedir(), realpath(target_dir))
        error("""
        target can not include home directory
          target: $(realpath(target_dir))
          home directory: $(homedir())
        """)
    end

    # Generate a closure with common commands for ssh and https
    function git_commands(sshconfig=nothing)
        # Setup git.
        run(`$(git()) init`)
        run(`$(git()) config user.name "Documenter.jl"`)
        run(`$(git()) config user.email "documenter@juliadocs.github.io"`)
        if sshconfig !== nothing
            run(`$(git()) config core.sshCommand "ssh -F $(sshconfig)"`)
        end

        # Fetch from remote and checkout the branch.
        run(`$(git()) remote add upstream $upstream`)
        try
            run(`$(git()) fetch upstream`)
        catch e
            @error """
            Git failed to fetch $upstream
            This can be caused by a DOCUMENTER_KEY variable that is not correctly set up.
            Make sure that the environment variable is properly set up as a Base64-encoded string
            of the SSH private key. You may need to re-generate the keys with DocumenterTools.
            """
            rethrow(e)
        end

        try
            run(`$(git()) checkout -b $branch upstream/$branch`)
        catch e
            @info """
            Checking out $branch failed, creating a new orphaned branch.
            This usually happens when deploying to a repository for the first time and
            the $branch branch does not exist yet. The fatal error above is expected output
            from Git in this situation.
            """
            @debug "checking out $branch failed with error: $e"
            run(`$(git()) checkout --orphan $branch`)
            run(`$(git()) commit --allow-empty -m "Initial empty commit for docs"`)
        end

        # Copy docs to `subfolder` directory.
        deploy_dir = subfolder === nothing ? dirname : joinpath(dirname, subfolder)
        gitrm_copy(target_dir, deploy_dir)

        if versions === nothing
            # If the documentation is unversioned and deployed to root, we generate a
            # siteinfo.js file that would disable the version selector in the docs
            HTMLWriter.generate_siteinfo_file(deploy_dir, nothing)
        else
            # Generate siteinfo-file with DOCUMENTER_CURRENT_VERSION
            HTMLWriter.generate_siteinfo_file(deploy_dir, subfolder)

            # Expand the users `versions` vector
            entries, symlinks = HTMLWriter.expand_versions(dirname, versions)

            # Create the versions.js file containing a list of `entries`.
            # This must always happen after the folder copying.
            HTMLWriter.generate_version_file(joinpath(dirname, "versions.js"), entries, symlinks)

            # Create the index.html file to redirect ./stable or ./dev.
            # This must always happen after the folder copying.
            HTMLWriter.generate_redirect_file(joinpath(dirname, "index.html"), entries)

            # generate the symlinks, make sure we don't overwrite devurl
            cd(dirname) do
                for kv in symlinks
                    i = findfirst(x -> x.first == devurl, symlinks)
                    if i === nothing
                        rm_and_add_symlink(kv.second, kv.first)
                    else
                        throw(ArgumentError(string("link `$(kv)` cannot overwrite ",
                            "`devurl = $(devurl)` with the same name.")))
                    end
                end
            end
        end

        # Add, commit, and push the docs to the remote.
        run(`$(git()) add -A .`)
        if !success(`$(git()) diff --cached --exit-code`)
            if !isnothing(archive)
                run(`$(git()) commit -m "build based on $sha"`)
                @info "Skipping push and writing repository to an archive" archive
                run(`$(git()) archive -o $(archive) HEAD`)
            elseif forcepush
                run(`$(git()) commit --amend --date=now -m "build based on $sha"`)
                run(`$(git()) push -fq upstream HEAD:$branch`)
            else
                run(`$(git()) commit -m "build based on $sha"`)
                run(`$(git()) push -q upstream HEAD:$branch`)
            end
        else
            @debug "new docs identical to the old -- not committing nor pushing."
        end
    end

    if authentication_method(deploy_config) === SSH
        # Get the parts of the repo path and create upstream repo path
        user, host, upstream = user_host_upstream(repo)

        keyfile = abspath(joinpath(homedir(), ".documenter-identity-file.tmp"))
        ispath(keyfile) && error("Keyfile not cleaned up from last run: $(keyfile)")
        try
            if is_preview
                keycontent = documenter_key_previews(deploy_config)
            else
                keycontent = documenter_key(deploy_config)
            end
            write(keyfile, base64decode(keycontent))
            chmod(keyfile, 0o600) # user-only rw permissions
        catch e
            @error """
            Documenter failed to decode the DOCUMENTER_KEY environment variable.
            Make sure that the environment variable is properly set up as a Base64-encoded string
            of the SSH private key. You may need to re-generate the keys with DocumenterTools.
            """
            rm(keyfile; force=true)
            rethrow(e)
        end

        try
            mktemp() do sshconfig, io
                print(io,
                """
                Host $host
                    StrictHostKeyChecking no
                    User $user
                    HostName $host
                    IdentityFile "$keyfile"
                    IdentitiesOnly yes
                    BatchMode yes
                """)
                close(io)
                chmod(sshconfig, 0o600)
                # git config core.sshCommand requires git 2.10.0, but
                # GIT_SSH_COMMAND works from 2.3.0 so define both.
                withenv("GIT_SSH_COMMAND" => "ssh -F $(sshconfig)", NO_KEY_ENV...) do
                    cd(() -> git_commands(sshconfig), temp)
                end
            end
            post_status(deploy_config; repo=repo, type="success", subfolder=subfolder)
        catch e
            @error "Failed to push:" exception=(e, catch_backtrace())
            post_status(deploy_config; repo=repo, type="error")
            rethrow(e)
        finally
            # Remove the unencrypted private key.
            isfile(keyfile) && rm(keyfile)
        end
    else # authentication_method(deploy_config) === HTTPS
        # The upstream URL to which we push new content authenticated with token
        upstream = authenticated_repo_url(deploy_config)
        try
            cd(() -> withenv(git_commands, NO_KEY_ENV...), temp)
            post_status(deploy_config; repo=repo, type="success", subfolder=subfolder)
        catch e
            @error "Failed to push:" exception=(e, catch_backtrace())
            post_status(deploy_config; repo=repo, type="error")
            rethrow(e)
        end
    end
end

function rm_and_add_symlink(target, link)
    if ispath(link) || islink(link)
        @warn "removing `$(link)` and linking `$(link)` to `$(target)`."
        rm(link; force = true, recursive = true)
    end
    symlink(target, link)
end

"""
    user_host_upstream(repo)

Disassemble repo address into user, host, and path to repo. If no user is given, default to
"git". Reassemble user, host and path into an upstream to `git push` to.
"""
function user_host_upstream(repo)
    # If the repo path contains the protocol, throw immediately an error.
    occursin(r"^[a-z]+://", repo) && error("The repo path $(repo) should not contain the protocol")
    #= the regex has three parts:
    (?:([^@]*)@)?  matches any number of characters up to the first "@", if present,
        capturing only the characters before the "@" - this captures the username
    (?:([^\/:]*)[\/:]){1}  matches exactly one instance of any number of characters
        other than "/" or ":" up to the first "/" or ":" - this captures the hostname
    [\/]?(.*)  matches the rest of the repo, except an initial "/" if present (e.g. if
        repo is of the form usr@host:/path/to/repo) - this captures the path on the host
    =#
    m = match(r"(?:([^@]*)@)?(?:([^\/:]*)[\/:]){1}[\/]?(.*)", repo)
    (m === nothing) && error("Invalid repo path $repo")
    user, host, pth = m.captures
    user = (user === nothing) ? "git" : user
    upstream = "$user@$host:$pth"
    return user, host, upstream
end

"""
    gitrm_copy(src, dst)

Uses `git rm -r` to remove `dst` and then copies `src` to `dst`. Assumes that the working
directory is within the git repository of `dst` is when the function is called.

This is to get around [#507](https://github.com/JuliaDocs/Documenter.jl/issues/507) on
filesystems that are case-insensitive (e.g. on OS X, Windows). Without doing a `git rm`
first, `git add -A` will not detect case changes in filenames.
"""
function gitrm_copy(src, dst)
    # Remove individual entries since with versions=nothing the root
    # would be removed and we want to preserve previews
    if isdir(dst)
        for x in filter!(!in((".git", "previews")), readdir(dst))
            # --ignore-unmatch so that we wouldn't get errors if dst does not exist
            run(`$(git()) rm -rf --ignore-unmatch $(joinpath(dst, x))`)
        end
    end
    # git rm also remove parent directories
    # if they are empty so need to mkpath after
    mkpath(dst)
    # Copy individual entries rather then the full folder since with
    # versions=nothing it would replace the root including e.g. the .git folder
    for x in readdir(src)
        cp(joinpath(src, x), joinpath(dst, x); force=true)
    end
end
