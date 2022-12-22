module ErrorsModule

"""
```jldoctest
julia> a = 1
2

```

```jldoctest
```
"""
func(x) = x

end

using Documenter, Test

makedocs(sitename="-", modules = [ErrorsModule])

for strict in (true, :doctest, [:doctest])
    @test_throws ErrorException makedocs(modules = [ErrorsModule], strict = strict)
end

# The following tests check that we can somewhat handle bad docsystem metadata. Issues:
#
#  - https://github.com/JuliaDocs/Documenter.jl/issues/1192
#  - https://github.com/JuliaDocs/Documenter.jl/issues/1810
#  - https://github.com/JuliaDocs/Documenter.jl/pull/1811
#  - https://github.com/JuliaLang/julia/issues/45174
#
module BadDocmetaModule
struct TestStruct1 end
struct TestStruct2 end
struct TestStruct3 end

"standard"
(baz::TestStruct1)(a::Int) = 0

"parametric"
(foo::TestStruct2)(a::T) where T = 0

"return"
(bar::TestStruct3)(a::Int, b::Int) :: Int = 0
end

@test makedocs(
    strict = Documenter.except(:autodocs_block),
    source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
) === nothing
@test makedocs(
    strict=false,
    source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
) === nothing
if VERSION >= v"1.9.0-DEV.954"
    # The docsystem metadata for the following tests was fixed in
    #   https://github.com/JuliaLang/julia/pull/45529
    @test makedocs(
        strict = true,
        source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
    ) === nothing
    @test makedocs(
        strict = :autodocs_block,
        source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
    ) === nothing
else
    @test_throws ErrorException makedocs(
        strict = true,
        source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
    )
    @test_throws ErrorException makedocs(
        strict = :autodocs_block,
        source = "src.docmeta", modules = [BadDocmetaModule], sitename="-", checkdocs = :exports,
    )
end
