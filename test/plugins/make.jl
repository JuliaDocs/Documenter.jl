module PluginsTestModule

# Test the documented behavior of `Plugin` and `getplugin`.

using Documenter, Test


# Flag whether the runner should do testing
mutable struct _RunPluginTests <: Documenter.Plugin
    enabled::Bool
    _RunPluginTests(enabled = false) = new(enabled)
end


mutable struct _TestPluginA <: Documenter.Plugin
    processed::Bool
    # no empty constructor: must be passed as object
end

mutable struct _TestPluginB <: Documenter.Plugin
    processed::Bool
    _TestPluginB() = new(false)
    # empty constructor: can be instantiated on demand
end

mutable struct _TestPluginC <: Documenter.Plugin
    processed::Bool
    # no empty constructor: for checking error behavior
end


# Pipeline step for testing all of the above dummy plugins
abstract type _TestPlugins <: Documenter.Builder.DocumentPipeline end

# Run the pipeline early within DocumentPipeline (not that it really matters)
Documenter.Selectors.order(::Type{_TestPlugins}) = 0.001


function Documenter.Selectors.runner(::Type{_TestPlugins}, doc)

    # Not sure if this runner might hook itself into other tests as a
    # side-effect. Thus, we don't do anything unless the test was explicitly
    # enabled.
    return if Documenter.getplugin(doc, _RunPluginTests).enabled

        @info "_TestPlugins: testing plugin API"
        @show doc.plugins  # type => object or type, as passed to `makedocs`

        # Plugin with passed object
        @test _TestPluginA in keys(doc.plugins)
        A = Documenter.getplugin(doc, _TestPluginA)
        @test !(A.processed)
        A.processed = true
        @test A isa _TestPluginA

        # plugin with empty constructor (no object passed)
        @test !(_TestPluginB in keys(doc.plugins))
        B = Documenter.getplugin(doc, _TestPluginB)
        @test !(B.processed)
        B.processed = true
        @test B isa _TestPluginB

        # subsequent calls to getplugin() should return the same object
        B2 = Documenter.getplugin(doc, _TestPluginB)
        @test B2.processed
        @test B2 === B

        # Missing object (no empty constructor)
        @test !(_TestPluginC in keys(doc.plugins))
        @test_throws MethodError begin
            # getplugin is going to try to instantiate `_TestPluginC()`
            C = Documenter.getplugin(doc, _TestPluginC)
        end

    end

end


A = _TestPluginA(false)
@test !(A.processed)
@test !(_TestPluginB().processed)
@test makedocs(;
    plugins = [_RunPluginTests(true), A],
    sitename = "-", modules = [PluginsTestModule], warnonly = false
) === nothing
@test A.processed


# Errors


# The documentation for Plugin/getplugin made it sound like passing a Plugin
# class instead of a plugin object to `makedocs` was a possibility. This was
# never true, and we check here the specific error that is being thrown if
# someone were to try it.
err_msg = "DataType in `plugins=` is not a subtype of `Documenter.Plugin`."
@test_throws ArgumentError(err_msg) begin
    makedocs(;
        plugins = [_RunPluginTests(false), _TestPluginB],
        sitename = "-", modules = [PluginsTestModule], warnonly = false
    )
end


# Only one instance of any given Plugin can be passed.
try  # Use try-catch get get around @test_throws limitations in Julia 1.6
    makedocs(;
        plugins = [_RunPluginTests(false), _TestPluginA(true), _TestPluginA(false)],
        sitename = "-", modules = [PluginsTestModule], warnonly = false
    )
    @test false  # makedocs should have thrown an ArgumentError
catch exc
    @test exc isa ArgumentError
    @test occursin(r"only one copy of .*_TestPluginA may be passed", exc.msg)
end


# Doctests  - the `doctest` function must also be able to process plugins

A = _TestPluginA(false)
@test !(A.processed)
doctest(
    joinpath(@__DIR__, "src"),
    [PluginsTestModule];
    plugins = [_RunPluginTests(true), A]
)
@test A.processed

end
