# Theming

<!-- TODO: change namings to not have "documenter" -->
<!-- TODO: add final links for Julia dynamics once this is done -->

It is possible to modify the default theme that Documenter.jl provides for the default native HTML documentation build.
This is done by simply modifying the default `.scss` files Documenter.jl has for either the light or the dark theme.
These two theme files are found in [Documenter.jl assets](https://github.com/JuliaDocs/Documenter.jl/tree/master/assets/html/scss) folder.

The steps that go into making your own theme are as follows (there is an example at the end):

1. Create a `light.scss` and/or a `dark.scss` file in your documentation's root folder (or any subfolder).
2. Edit these style files to overwrite the variables defined in Documenter's style files. The customizable variables can be found in the [scss assets of Documenter.jl](
https://github.com/JuliaDocs/Documenter.jl/tree/master/assets/html/scss), specifically under `documenter/_variables` or `documenter/_overrides`. Some variables are in fact [Bulma defaults](https://bulma.io/documentation/customize/variables/), so you may need to look them up too.
1. The first command of your style file has to be `$themename: "documenter-light";`, while the last command has to be `@import "documenter-light";` (similarly for dark version). This ensures that the existing variables of the default theme will be used and overwritten as appropriate.
3. In your `make.jl` file, recompile Documenter's themes using the command:
   ```julia
   Themes.compile(joinpath(@__DIR__, "light.scss"), joinpath(@__DIR__, "src/assets/themes/documenter-light.css"))
   ```
   and similarly for the dark version.

Try to for example to make a `light.scss` file with only contents
```
$themename: "documenter-light";
$text: #b31616;
@import "documenter-light";
```
and this should change your main text color to a red hue.
Notice that if you want to change fonts with e.g. `$family-sans-serif: 'Montserrat', sans-serif;`, then you should include these fonts into the assets argument of the HTML writer through the `format` keyword of `makedocs`:
```julia
format = Documenter.HTML(
    assets = [
        "assets/logo.ico",
        asset("https://fonts.googleapis.com/css?family=Montserrat|Source+Code+Pro&display=swap", class=:css),
        ],
    ),
```

## Examples
Here are some packages that have used this theming process:
* [DrWatson](https://juliadynamics.github.io/DrWatson.jl/previews/PR127/)
