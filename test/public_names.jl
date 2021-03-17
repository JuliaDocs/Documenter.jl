using Documenter
using Test

module TestingNonExportedPublicNames

export f

const NONEXPORTED_PUBLIC_NAMES = Symbol[:g]

"""
f is exported, and it is part of the public API
"""
function f end

"""
g is not exported, but it is part of the public API
"""
function g end

"""
h is not exported, and it is private (internal)
"""
function h end

end # module

@test Documenter.Expanders.name_is_public(TestingNonExportedPublicNames, :f)
@test Documenter.Expanders.name_is_public(TestingNonExportedPublicNames, :g)
@test !Documenter.Expanders.name_is_public(TestingNonExportedPublicNames, :h)

@test Base.isexported(TestingNonExportedPublicNames, :f)
@test !Base.isexported(TestingNonExportedPublicNames, :g)
@test !Base.isexported(TestingNonExportedPublicNames, :h)

@test !Documenter.Expanders._name_is_public_but_nonexported(TestingNonExportedPublicNames, :f)
@test Documenter.Expanders._name_is_public_but_nonexported(TestingNonExportedPublicNames, :g)
@test !Documenter.Expanders._name_is_public_but_nonexported(TestingNonExportedPublicNames, :h)

module BadNONEXPORTED_PUBLIC_NAMES

const NONEXPORTED_PUBLIC_NAMES = "foo"

function f end

end # module

@test @test_logs match_mode=:any (:warn, r"BadNONEXPORTED_PUBLIC_NAMES\.NONEXPORTED_PUBLIC_NAMES is not a vector of symbols, so Documenter will ignore it") !Documenter.Expanders.name_is_public(BadNONEXPORTED_PUBLIC_NAMES, :f)
