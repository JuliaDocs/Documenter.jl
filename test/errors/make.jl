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

makedocs(sitename = "-", modules = [ErrorsModule], warnonly = true)

for warnonly in (false, :autodocs_block, [:autodocs_block])
    # The build should fail with a :doctest error
    @test_throws ErrorException makedocs(modules = [ErrorsModule], warnonly = warnonly)
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
    (foo::TestStruct2)(a::T) where {T} = 0

    "return"
    (bar::TestStruct3)(a::Int, b::Int)::Int = 0
end

@test makedocs(
    warnonly = :autodocs_block,
    source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
) === nothing
@test makedocs(
    warnonly = true,
    source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
) === nothing
if VERSION >= v"1.9.0-DEV.954"
    # The docsystem metadata for the following tests was fixed in
    #   https://github.com/JuliaLang/julia/pull/45529
    @test makedocs(
        source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
    ) === nothing
    @test makedocs(
        warnonly = Documenter.except(:autodocs_block),
        source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
    ) === nothing
else
    @test_throws ErrorException makedocs(
        source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
    )
    @test_throws ErrorException makedocs(
        warnonly = Documenter.except(:autodocs_block),
        source = "src.docmeta", modules = [BadDocmetaModule], sitename = "-", checkdocs = :exports,
    )
end
