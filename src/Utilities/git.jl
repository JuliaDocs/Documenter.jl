# This code is derived from the implementation in the Git.jl package (MIT License):
#
# Copyright (c) 2019 Dilum Aluthge and contributors
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

using Git_jll: Git_jll

function git(; adjust_PATH::Bool = true, adjust_LIBPATH::Bool = true)
    @static if Sys.iswindows()
        return Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
    elseif Sys.isapple()
        # The Git_jll does not work properly on Macs, so we fall back to the
        # system binaries here.
        #
        # https://github.com/JuliaVersionControl/Git.jl/issues/40#issuecomment-1144307266
        # https://github.com/JuliaPackaging/Yggdrasil/pull/4987
        success(`which which`) || error("Unable to find `which`")
        success(`which git`) || error("Unable to find `git`")
        system_git_path = strip(read(`which git`, String))
        # According to the Git man page, the default GIT_TEMPLATE_DIR is at /usr/share/git-core/templates
        # We need to set this to something so that Git wouldn't pick up the user
        # templates (e.g. from init.templateDir config).
        return addenv(`$(system_git_path)`, "GIT_TEMPLATE_DIR" = "/usr/share/git-core/templates")
    else
        root = Git_jll.artifact_dir

        libexec = joinpath(root, "libexec")
        libexec_git_core = joinpath(libexec, "git-core")

        share = joinpath(root, "share")
        share_git_core = joinpath(share, "git-core")
        share_git_core_templates = joinpath(share_git_core, "templates")

        ssl_cert = joinpath(dirname(Sys.BINDIR), "share", "julia", "cert.pem")

        env_mapping = Dict{String,String}()
        env_mapping["GIT_EXEC_PATH"]    = libexec_git_core
        env_mapping["GIT_SSL_CAINFO"]   = ssl_cert
        env_mapping["GIT_TEMPLATE_DIR"] = share_git_core_templates

        original_cmd = Git_jll.git(; adjust_PATH, adjust_LIBPATH)::Cmd
        return addenv(original_cmd, env_mapping...)::Cmd
    end
end
