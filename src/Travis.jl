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

which() = foreach(test_for, ("which", "ssh-keygen", "travis") )

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
    if !success(`ssh-keygen -f $filename`)
        error("Cannot generate ssh keys")
    end
end

basic_info(user, repo_name) =
    try
        readstring(`curl https://api.travis-ci.org/repos/$user/$repo_name`) |>
            JSON.Parser.parse
    catch
        error("Cannot get basic info from Travis for $user/$repo_name")
    end


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
    url = "https://api.travis-ci.org/settings/env_vars?repository_id=$repository_id"
    header = "Authorization: token $token"
    if !success(`curl $url --header $header --data $data`)
        error("Cannot submit key to Travis")
    end
end

function unix_genkeys(user, repo_name)
    filename  = ".documenter"
    which()

    mktempdir() do tmp
        cd(tmp) do
            ssh_keygen(filename)
            GitHub.submit_keys(user, repo_name, "documenter", readstring( filename * ".pub" ) )
            env_vars(basic_info(user, repo_name)["id"], token(),
                     "DOCUMENTER_KEY", readstring(filename) |> base64encode)
        end
    end
end

"""
$(SIGNATURES)

Generate ssh keys for package `package` to automatically deploy docs from Travis to GitHub
pages. `package` can be either the name of a package or a path. Providing a path allows keys
to be generated for non-packages or packages that are not found in the Julia `LOAD_PATH`.
Provide your github username: `user` and the repository name: `repo`. `path_additions` are additional
folders to **temporarily** add to your path if they exist; defaults to
`["C:/Program Files/Git/usr/bin"]` on Windows.

This function requires the following command line programs to be installed and
on your path:

- `which`
- `ssh-keygen`
- `travis`

For Windows users, the first two might be packaged with Git in
`C:/Program Files/Git/usr/bin`. Install travis with ruby: `gem install travis`.

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
genkeys(user, repo_name; path_additions = Utilities.platform_paths() ) =
    withenv(Utilities.add_to_path(path_additions) ) do
        unix_genkeys(user, repo_name)
    end

end
