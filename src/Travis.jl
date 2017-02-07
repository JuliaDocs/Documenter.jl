export Travis

"""
Package functions for interacting with Travis.

$(EXPORTS)
"""
module Travis

using Compat, DocStringExtensions
import JSON
import ..Documenter:
    Utilities,
    GitHub

export genkeys

test_for(program) = if !success(`which $program`)
    error("$program not found.")
end

which() = foreach(test_for, ("which", "git", "ssh-keygen", "travis") )

windows_prefix() = if is_windows()
    `cmd /c`
else
    ``
end

function ssh_keygen(filename)
    info("Generating key")
    if isfile("$filename.enc")
        error("ssh key already exists. Remove it and try again.")
    end
    Utilities.abbreviated_command_line("ssh-keygen", f = filename) |> run
end

basic_info(user, repo) =
    readstring(`curl https://api.travis-ci.org/repos/$user/$repo`) |>
    JSON.Parser.parse

function token()
    info("Creating travis token")
    prefix = windows_prefix()
    run(`$prefix travis login`)
    token_string = readstring(`$prefix travis token`) |> chomp
    split(token_string, " ")[end]
end

function env_vars(repository_id, token, name, value; public = false)
    info("Submitting key to travis")
    env_var = Dict(
        "name" => name,
        "value" => value,
        "public" => public)
    data = Dict("env_var" => env_var) |> JSON.json
    Utilities.command_line(:curl,
        "https://api.travis-ci.org/settings/env_vars?repository_id=$repository_id",
        header = "Authorization: token $token", data = data) |> run
end

function unix_genkeys(package, user, repo)
    filename  = ".documenter"

    path = Utilities.expand_path(package, "docs")
    print(path)

    cd(path) do
        which()
        ssh_keygen(filename)

        public_filename = string(filename, ".pub")
        GitHub.submit_keys(user, repo, "documenter", readstring(public_filename) )
        rm(public_filename)

        env_vars(
            basic_info(user, repo)["id"], token(),
            "DOCUMENTER_KEY", readstring(filename) |> base64encode)
        rm(filename)
    end
end

"""
$(SIGNATURES)

Generate ssh keys for package `package` to automatically deploy docs from Travis to GitHub
pages. `package` can be either the name of a package or a path. Providing a path allows keys
to be generated for non-packages or packages that are not found in the Julia `LOAD_PATH`.
Provide your github username: `user` and the repository name: `repo`. `extras` are additional
folders to **temporarily** add to your path if they exist; defaults to
["C:/Program Files/Git/usr/bin"].

This function requires the following command line programs to be installed and
on your path:

- `which`
- `git`
- `ssh-keygen`
- `travis`

For Windows users, the first three might be packaged with Git in
"C:/Program Files/Git/usr/bin". Install travis with ruby: `gem install travis`.

# Examples

```jlcon
julia> using Documenter

julia> Travis.genkeys("MyPackageName")
[ ... output ... ]

julia> Travis.genkeys("MyPackageName", remote="organization")
[ ... output ... ]

julia> Travis.genkeys("/path/to/target/directory")
[ ... output ... ]
```
"""
genkeys(package, user, repo; extras = ["C:/Program Files/Git/usr/bin"] ) =
    withenv(Utilities.add_to_path(extras) ) do
        unix_genkeys(package, user, repo)
    end

end
