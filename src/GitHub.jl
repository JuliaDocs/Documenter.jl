module GitHub

import JSON

const GITHUB_REGEX = isdefined(Base, :LibGit2) ?
    Base.LibGit2.GITHUB_REGEX : Base.Pkg.Git.GITHUB_REGEX

get_repo(path) =
    try
        LibGit2.GitRepo(path)
    catch
        "Cannot find git repository at $path"
    end

function remote_url(repo; remote = "origin")
    url = LibGit2.getconfig(repo, "remote.$remote.url", "default")
    if url == "default"
        error("Cannot find url for remote $remote")
    else
        url
    end
end

function user_repo_name(repo; remote = "origin")
    matches = match(GITHUB_REGEX, remote_url(repo, remote = remote))
    matches[2], matches[3]
end

function submit_keys(user, repo_name, title, key; read_only = false)
    info("Submitting key to GitHub")
    data = Dict("title" => title,
                "key" => key,
                "read_only" => read_only) |>
        JSON.json
    url = "https://api.github.com/repos/$user/$repo_name/keys"
    if !success(`curl $url --user $user --request POST --data $data`)
        error("Cannot push key to github")
    end
end

function test_push(repo; remote = remote)
    try
        LibGit2.push(repo; remote = remote)
    catch
        error("Cannot push to remote $remote")
    end
end

function branch_push(repo; branch = "gh-pages", remote = "origin")
    info("Adding and pushing $branch branch")
    current_branch = LibGit2.branch(repo)
    test_push(repo, remote = remote)
    LibGit2.branch!(repo, branch)
    LibGit2.GitCommit
    test_push(repo, remote = remote)
    LibGit2.branch!(repo, current_branch)
end

end
