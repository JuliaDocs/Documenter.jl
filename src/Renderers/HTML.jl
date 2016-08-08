module HTML

import ...DocTrees
import ..Renderers

#
# The following sets are based on:
#
# - https://developer.mozilla.org/en/docs/Web/HTML/Block-level_elements
# - https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements
# - https://developer.mozilla.org/en-US/docs/Glossary/empty_element
#
const BLOCK_ELEMENTS = Set([
    :address, :article, :aside, :blockquote, :canvas, :dd, :div, :dl,
    :fieldset, :figcaption, :figure, :footer, :form, :h1, :h2, :h3, :h4, :h5,
    :h6, :header, :hgroup, :hr, :li, :main, :nav, :noscript, :ol, :output, :p,
    :pre, :section, :table, :tfoot, :ul, :video,
])
const INLINE_ELEMENTS = Set([
    :a, :abbr, :acronym, :b, :bdo, :big, :br, :button, :cite, :code, :dfn, :em,
    :i, :img, :input, :kbd, :label, :map, :object, :q, :samp, :script, :select,
    :small, :span, :strong, :sub, :sup, :textarea, :time, :tt, :var,
])
const VOID_ELEMENTS = Set([
    :area, :base, :br, :col, :command, :embed, :hr, :img, :input, :keygen,
    :link, :meta, :param, :source, :track, :wbr,
])
const ALL_ELEMENTS = union(BLOCK_ELEMENTS, INLINE_ELEMENTS, VOID_ELEMENTS)


function Renderers.render(io::IO, mime::MIME"text/html", node::DocTrees.Node)
    if DocTrees.istext(node)
        Renderers.escape(io, mime, node.text)
    else
        print(io, '<', node.tag)
        for (name, value) in Renderers.attributes(node, mime)
            isempty(value) || print(io, ' ', name, '=', repr(value))
        end
        if node.tag in VOID_ELEMENTS
            print(io, "/>")
        else
            print(io, '>')
            if node.tag in (:script, :style)
                isempty(node.nodes) || print(io, node.nodes[1].text)
            else
                Renderers.render(io, mime, node.nodes)
            end
            print(io, "</", node.tag, '>')
        end
    end
end

end
