module GitHub

import JSON
import ..Documenter:
    Utilities

const GITHUB_REGEX = isdefined(Base, :LibGit2) ?
    Base.LibGit2.GITHUB_REGEX : Base.Pkg.Git.GITHUB_REGEX

is_git(path = pwd() ) = cd(path) do
    if !success(`git status`)
        error("Must be a git repository")
    end
end

function user_repo(; path = pwd(), remote = "origin")
    is_git(path)
    config = cd(path) do
        readchomp(`git config --get remote.$remote.url`)
    end
    matches = match(GITHUB_REGEX, config)
    if matches === nothing
        error("no remote repo named '$remote' found.")
    end
    matches[2], matches[3]
end

function submit_keys(user, repo, title, key; read_only = false)
    info("Submitting key to GitHub")
    data = Dict("title" => title,
                "key" => key,
                "read_only" => read_only) |>
        JSON.json
    Utilities.command_line(:curl, "https://api.github.com/repos/$user/$repo/keys",
                           user = user, request = :POST, data = data) |> run
end

function branch_push(branch; remote = "origin", path = pwd() )
    info("Adding and pushing gh-pages branch")
    is_git(path)
    if !success(`git branch $branch`)
        info("gh-pages branch already exists")
    end
    run(`git push $remote $branch`)
end

end
