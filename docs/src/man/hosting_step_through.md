# SSH Deploy Keys - the walkthrough

If the instructions in [SSH Deploy Keys](@ref) did not work for you (for
example, `ssh-keygen` is not installed), don't worry! This walkthrough will
guide you through the process. There are three main steps
1. [Generate a key](@ref)
2. [Add the public key to Github](@ref)
3. [Add the private key to Travis](@ref)

## Generate a key

The first step is to generate an SSH key. The SSH key is made up of two
components: a *public* key, which can be shared publicly, and a *private* key,
which you should  ensure is **never** shared publicly.

The public key should look something like
```
ssh-rsa [lots of characters]== [optional comment]
```
The private key should look something like
```
-----BEGIN RSA PRIVATE KEY-----
 ... lots of lines of characters ...
-----END RSA PRIVATE KEY-----
```

### Windows

If you're using Windows, you probably don't have `ssh-keygen` installed.
Instead, we're going to use a program called PuTTY. The first step in the
process to generate a new SSH key is to download PuTTY:

 - Download and install [PuTTY](https://www.ssh.com/ssh/putty/download)

PuTTY is actually a collection of a few different programs. We need to use
PuTTYgen. Open it, and you should get a window that looks like:

![](https://user-images.githubusercontent.com/8177701/45131792-a09a6b80-b1e2-11e8-885b-499237651c29.png)

Now we need to generate a key.

- Click the `Generate` button, then follow the instructions and move the mouse
  around to create randomness.

Once you've moved the mouse enough, the window should look like:

![](https://user-images.githubusercontent.com/8177701/45131800-a728e300-b1e2-11e8-8d40-dbb4fa383ff5.png)

Now we need to save the public key somewhere.

- Copy the text in the box titled `Public key for pasting into OpenSSH
  authorized_keys file` and paste it somewhere for later. This is your *public
  key* and is required for the step [Add the public key to Github](@ref)

Finally, we need to save the private key somewhere.

- Click the `Conversions` tab, and then click `Export OpenSSH key`. Save that
  file somewhere. That file is your *private key* and is required for the step
  [Add the private key to Travis](@ref)

![](https://user-images.githubusercontent.com/8177701/45131813-b4de6880-b1e2-11e8-82bd-ec8ceb44a976.png)

!!! info
    Don't save your key via the `Save private key` button as this will save the
    key in the wrong format.

If you made it this far, congratulations! We now have the private and public
keys needed by Documenter. The next step is to add the public key to Github.

## Add the public key to Github

In this section, we explain how to upload a public SSH key to Github. By this
point, you should have generated a public key and saved it to a file. If you
haven't done this, go read [Generate a key](@ref).

- Go to [https://github.com/[YOUR_USER_NAME]/[YOUR_REPO_NAME]/settings/keys]()
  and click `Add deploy key`. You should get to a page that looks like:

![](https://user-images.githubusercontent.com/8177701/45131985-4fd74280-b1e3-11e8-9d95-46539845ee3a.png)

Now we need to fill in three pieces of information.

1. Make the `Title` `documenter`.
2. Copy and paste the *public* key that we generated in the [Generate a key](@ref)
   step into the `Key` field.
3. Make sure that the `Allow write access` box is checked.

Once you're done, click `Add key`. Congratulations! You've added the public key
to Github. The next step is to add the private key to Travis.

## Add the private key to Travis

In this section, we explain how to upload a private SSH key to Travis. By this
point, you should have generated a private key and saved it to a file. If you
haven't done this, go read [Generate a key](@ref).

First, we need to Base64 encode the private key. Open Julia, and run the command
```julia
julia> read("path/to/private/key", String) |> Documenter.base64encode |> println
```
Copy the resulting output.

Next, go to [https://travis-ci.org/[YOUR_USER_NAME]/[YOUR_REPO_NAME]/settings]().
Scroll down to the `Environment Variables` section. It looks like this:

![](https://user-images.githubusercontent.com/8177701/45132034-801ee100-b1e3-11e8-8152-b407f0e89770.png)

Now, add a new environment variable. Set the name to `DOCUMENTER_KEY`, and the
value of the environment variable to the output from the Julia command above
(make sure to remove the surrounding quotes).

Finally, check that the "Display value in build log" is switched off and then
click `Add`. Congratulations! You've added the private key to Travis.

You should be able to continue on with the [Hosting Documentation](@ref).
