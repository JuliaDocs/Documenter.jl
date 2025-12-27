// Import mitex for LaTeX math rendering
#import "@preview/mitex:0.2.6": *

#let light-blue = rgb("6b85dd")
#let dark-blue = rgb("4266d5")
#let light-red = rgb("d66661")
#let dark-red = rgb("c93d39")
#let light-green = rgb("6bab5b")
#let dark-green = rgb("3b972e")
#let light-purple = rgb("aa7dc0")
#let dark-purple = rgb("945bb0")
#let codeblock-background = rgb("f6f6f6")
#let codeblock-border = rgb("e6e6e6")
#let admonition-colors = (
    default: rgb("363636"),
    danger: rgb("da0b00"),
    warning: rgb("ffdd57"),
    note: rgb("209cee"),
    info: rgb("209cee"),
    tip: rgb("22c35b"),
    compat: rgb("1db5c9")
)
#let admonition-titles = (
    default: "Note",
    danger: "Danger",
    warning: "Warning",
    note: "Note",
    info: "Info",
    tip: "Tip",
    compat: "Compatibility"
)

#let partcounter = counter("part")
#let chaptercounter = counter("chapter")

#let ceil(len, unit: 4pt) = calc.ceil(len / unit) * unit

#let admonition(type: "info", title: none, children) = {
    let color = admonition-colors.at(type)
    let bgcolor = color.lighten(50%)
    if title == none {
        title = admonition-titles.at(type)
    }

    rect(width: 100%, fill: color, radius: 5pt, inset: 5pt)[
        #h(1em)
        #text(12pt, fill: white)[#strong(title)]
        #v(-0.5em)
        #rect(width: 100%, fill: bgcolor, inset: 10pt)[
            #children
        ]
    ]
}

#let extended_heading(level: 0, outlined: true, within-block: false, body) = {
    if not within-block and level <= 2 {
        pagebreak(weak: true)
    }

    heading(level: level, outlined: outlined, body)
}

#let outline(title: "Contents", indent: true, depth: 3) = context {
    let loc = here()
    partcounter.step()
    counter(page).update(1)

    heading(level: 2, numbering: none, outlined: false, [#title])

    let elements = query(heading.where(outlined: true)).filter(h => h.location().page() > loc.page())
    for el in elements {
        // Skip headings that are too deep
        if depth != none and el.level > depth { continue }
        let el_loc = el.location();

        let maybe_number = if el.numbering != none {
            if el.level == 1 {
                numbering("I", ..counter(heading).at(el_loc))
            } else if el.level == 2 {
                numbering("1.1", chaptercounter.at(el_loc).first() + 1)
            } else {
                numbering("1.1", ..chaptercounter.at(el_loc), ..counter(heading).at(el_loc).slice(2))
            }
            h(0.5em)
        }

        if indent {
            h(1em * (el.level - 1 ))
        }

        if el.level == 1 {
            v(0.5em, weak: true)
        }

        if maybe_number != none {
            link(el_loc, box(
                if el.level == 1 { 
                    strong(maybe_number) 
                } else { 
                    maybe_number 
                }
            ))
        }

        link(el_loc, if el.level == 1 {
            strong(el.body)
        } else {
            el.body
        })

        // Filler dots
        if el.level == 1 {
            box(width: 1fr, h(10pt) + box(width: 1fr) + h(10pt))
        } else {
            box(width: 1fr, h(10pt) + box(width: 1fr, repeat[.]) + h(10pt))
        }
        
        // Page number
        let page_number = counter(page).at(el_loc).first()
        
        link(el_loc, if el.level == 1 {
            strong(str(page_number))
        } else {
            str(page_number)
        })

        linebreak()
        v(-0.2em)
    }
}

#let documenter(
    title: none,
    date: none,
    version: none,
    authors: none,
    julia-version: none,
    linespacing: 1em,
    doc
) = {
    set heading(numbering: "1.1")

    set list(
        marker: ([•], [--], [∗], [•], [--], [∗], [•], [--], [∗]),
        spacing: linespacing,
    )

    set page(
        header: none,
        footer: context {
            if here().page() > 1 {
                align(center)[
                    #numbering("1", counter(page).get().first())
                ]
            }
        }
    )

    // Set color for links
    show link: it => {
        if type(it.dest) == "location" {
            text(fill: dark-blue)[#it]
        } else {
            text(fill: dark-purple)[#it]
        }
    }

    show raw: it => if it.lang != none {
        block(fill: codeblock-background, stroke: codeblock-border, width: 100%, inset: 5pt, radius: 5pt)[
            #it
        ]
    } else {
        it
    }

    show heading: it => context {
        let loc = here()
        if it.level == 1 {
            if partcounter.get().first() == 1 and it.numbering != none {
                partcounter.step()
                counter(page).update(1)
            }

            align(center + horizon)[
                #text(14pt)[
                    #strong([
                    Part 
                    #numbering("I", counter(heading).get().first())
                ])] <__part__>
                #v(1em)
                #text(18pt)[#strong(it.body)]
            ]
        } else if it.level == 2 {
            align(left + top)[
                #if it.numbering != none {
                    chaptercounter.step()
                    text(14pt)[
                        #strong([
                        Chapter
                        #numbering("1", chaptercounter.get().first() + 1)
                    ])] 
                    v(1em)
                }
                #text(18pt)[#strong(it.body)] <__chapter__>
                #v(1em)
            ]
        } else {
            v(0.5em)
            if it.level == 3 {         
                text(14pt)[
                #strong([
                    #numbering("1.1", chaptercounter.get().first(), ..counter(heading).get().slice(2))
                    #h(1em)
                    #it.body
                ])
                ]
            } else if it.level == 4 {
                text(13pt)[#strong(it.body)]
            } else if it.level <= 6 {
                text(12pt)[#strong(it.body)]
            } else {
                h(2em)
                text(12pt)[#strong(it.body)]
            }
            v(0.5em)
        }
    }

    show list: set par(justify: false)

    if title != none {
        align(center + horizon)[
            #text(24pt)[#strong[#title]]
            #v(2em)
            #if authors != none {
                text(12pt)[#strong[#authors]]
                v(2em)
            }
            #text(12pt)[#date]
            #pagebreak()
        ]
    }

    outline(depth: 3, indent: true)
    pagebreak()
    
    // Don't wrap doc in par() - it causes all content to be in one paragraph
    set par(justify: true)
    doc
}
