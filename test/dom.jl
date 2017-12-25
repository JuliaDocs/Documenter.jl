module DOMTests

using Compat.Test
using Compat

import Documenter.Utilities.DOM: DOM, @tags, HTMLDocument

@tags div ul li p

@testset "DOM" begin
    for tag in (:div, :ul, :li, :p)
        TAG = @eval $tag
        @test isa(TAG, DOM.Tag)
        @test TAG.name === tag
    end

    @test div().name === :div
    @test div().text == ""
    @test isempty(div().nodes)
    @test isempty(div().attributes)

    @test div("...").name === :div
    @test div("...").text == ""
    @test length(div("...").nodes) === 1
    @test div("...").nodes[1].text == "..."
    @test div("...").nodes[1].name === Symbol("")
    @test isempty(div("...").attributes)

    @test div[".class"]("...").name === :div
    @test div[".class"]("...").text == ""
    @test length(div[".class"]("...").nodes) === 1
    @test div[".class"]("...").nodes[1].text == "..."
    @test div[".class"]("...").nodes[1].name === Symbol("")
    @test length(div[".class"]("...").attributes) === 1
    @test div[".class"]("...").attributes[1] == (:class => "class")
    @test div[:attribute].attributes[1] == (:attribute => "")
    @test div[:attribute => "value"].attributes[1] == (:attribute => "value")

    let d = div(ul(map(li, [string(n) for n = 1:10])))
        @test d.name === :div
        @test d.text == ""
        @test isempty(d.attributes)
        @test length(d.nodes) === 1
        let u = d.nodes[1]
            @test u.name === :ul
            @test u.text == ""
            @test isempty(u.attributes)
            @test length(u.nodes) === 10
            for n = 1:10
                let v = u.nodes[n]
                    @test v.name === :li
                    @test v.text == ""
                    @test isempty(v.attributes)
                    @test length(v.nodes) === 1
                    @test v.nodes[1].name === Symbol("")
                    @test v.nodes[1].text == string(n)
                    @test !isdefined(v.nodes[1], :attributes)
                    @test !isdefined(v.nodes[1], :nodes)
                end
            end
        end
    end

    @tags script style img

    @test string(div(p("one"), p("two"))) == "<div><p>one</p><p>two</p></div>"
    @test string(div[:key => "value"])    == "<div key=\"value\"></div>"
    @test string(p(" < > & ' \" "))       == "<p> &lt; &gt; &amp; &#39; &quot; </p>"
    @test string(img[:src => "source"])   == "<img src=\"source\"/>"
    @test string(img[:none])              == "<img none/>"
    @test string(script(" < > & ' \" "))  == "<script> < > & ' \" </script>"
    @test string(style(" < > & ' \" "))   == "<style> < > & ' \" </style>"
    @test string(script)                  == "<script>"

    function locally_defined()
        @tags button
        @test try
            x = button
            true
        catch err
            false
        end
    end
    @test !isdefined(@__MODULE__, :button)
    locally_defined()
    @test !isdefined(@__MODULE__, :button)

    # HTMLDocument
    @test string(HTMLDocument(div())) == "<!DOCTYPE html>\n<div></div>\n"
    @test string(HTMLDocument("custom doctype", div())) == "<!DOCTYPE custom doctype>\n<div></div>\n"
end

end
