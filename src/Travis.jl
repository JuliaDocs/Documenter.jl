"""
Package functions for interacting with Travis.

$(EXPORTS)
"""
module Travis

using Compat, DocStringExtensions
import Compat.Pkg

export genkeys

import Compat.LibGit2.GITHUB_REGEX


"""
$(SIGNATURES)

Generate ssh keys for package `package` to automatically deploy docs from Travis to GitHub
pages. `package` can be either the name of a package or a path. Providing a path allows keys
to be generated for non-packages or packages that are not found in the Julia `LOAD_PATH`.
Use the `remote` keyword to specify the user and repository values.

This function requires the following command lines programs to be installed:

- `which`
- `git`
- `travis`
- `ssh-keygen`

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
function genkeys(package; remote="origin")
    # Error checking. Do the required programs exist?
    success(`which which`)      || error("'which' not found.")
    success(`which git`)        || error("'git' not found.")
    success(`which ssh-keygen`) || error("'ssh-keygen' not found.")

    directory = "docs"
    filename  = ".documenter"

    path = isdir(package) ? package : Pkg.dir(package, directory)
    isdir(path) || error("`$path` not found. Provide a package name or directory.")

    cd(path) do
        # Check for old '$filename.enc' and terminate.
        isfile("$filename.enc") &&
            error("$package already has an ssh key. Remove it and try again.")

        # Are we in a git repo?
        success(`git status`) || error("'Travis.genkey' only works with git repositories.")

        # Find the GitHub repo org and name.
        user, repo =
            let r = readchomp(`git config --get remote.$remote.url`)
                m = match(GITHUB_REGEX, r)
                m === nothing && error("no remote repo named '$remote' found.")
                m[2], m[3]
            end

        # Generate the ssh key pair.
        success(`ssh-keygen -N "" -f $filename`) || error("failed to generated ssh key pair.")

        # Prompt user to add public key to github then remove the public key.
        let url = "https://github.com/$user/$repo/settings/keys"
            Compat.@info("add the public key below to $url with read/write access:")
            println("\n", read("$filename.pub", String))
            rm("$filename.pub")
        end

        # Base64 encode the private key and prompt user to add it to travis. The key is
        # *not* encoded for the sake of security, but instead to make it easier to
        # copy/paste it over to travis without having to worry about whitespace.
        let url = "https://travis-ci.org/$user/$repo/settings"
            Compat.@info("add a secure environment variable named 'DOCUMENTER_KEY' to $url with value:")
            println("\n", base64encode(read(".documenter", String)), "\n")
            rm(filename)
        end
    end
end

end # module
