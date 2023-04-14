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

#let next_page(loc, label) = {
    let parts = query(selector(label).after(loc), loc)
    if parts.len() > 0 {
        parts.first().location().position().page
    } else {
        10000000
    }
}

#let last_page(loc, label) = {
    let parts = query(selector(label).before(loc), loc)
    if parts.len() > 0 {
        parts.last().location().position().page
    } else {
        -1
    }
}

#let next_part_or_chapter(loc) = {
    calc.min(
        next_page(loc, <__part__>),
        next_page(loc, <__chapter__>),
    )
}

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

#let outline(title: "Contents", indent: true, depth: 3) = locate(loc => {
    partcounter.step()
    counter(page).update(1)

    heading(level: 2, numbering: none, outlined: false, [#title])

    let elements = query(heading.where(outlined: true).after(loc), loc)
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
            style(styles => {
                let width = measure(maybe_number, styles).width
                link(el_loc, box(
                    width: ceil(width),
                    if el.level == 1 { 
                        strong(maybe_number) 
                    } else { 
                        maybe_number 
                    }
                ))
            })
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
        let footers = query(selector(<__footer__>).after(el_loc), el_loc)
        let page_number = if footers == () {
            0
        } else {
            counter(page).at(footers.first().location()).first()
        }
        
        link(el_loc, if el.level == 1 {
            strong(str(page_number))
        } else {
            str(page_number)
        })

        linebreak()
        v(-0.2em)
    }
})

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
        header: locate(loc => if loc.page() > 1 {
            let footers = query(selector(<__footer__>).before(loc), loc)
            if footers.len() > 0 {
                let footer = footers.last()
                let footer_loc = footer.location()
                if next_part_or_chapter(footer_loc) > loc.page() {
                    let chapters = query(heading.where(level: 2, outlined: true).before(footer_loc), footer_loc)
                    set align(center)
                    if chapters.len() > 0 {
                        let chapter = chapters.last()
                        [
                            Chapter
                            #(chaptercounter.at(chapter.location()).first() + 1).
                            #h(0.5em)
                            #chapter.body
                        ]
                    } else {
                        [Contents]
                    }
                    v(-0.85em)
                    line(length: 100%)
                }
            }
        }),
        footer: locate(loc => {
            [#box(width: 0em) <__footer__>]

            if loc.page() > 1 and last_page(loc, <__part__>) < loc.page() {
                align(center)[#locate(loc => 
                    [
                        #numbering(if partcounter.at(loc).first() < 2 {
                            "i"
                        } else {
                            "1"
                        }, counter(page).at(loc).first())
                    ]
                )] 
            }
        })
    )

    // Set color for links
    show link: it => if type(it.dest) == "label" {
        text(fill: dark-blue)[
            #locate(loc => if query(it.dest, loc) == () {
                it.body
            } else {
                it
            })
        ]
    } else if type(it.dest) == "location" {
        text(fill: dark-blue)[#it]
    } else {
        text(fill: dark-purple)[#it]
    }

    show raw: it => if it.lang != none {
        block(fill: codeblock-background, stroke: codeblock-border, width: 100%, inset: 5pt, radius: 5pt)[
            #it
        ]
    } else {
        it
    }

    show heading: it => locate(loc => {
        if it.level == 1 {
            if partcounter.at(loc).first() == 1 and it.numbering != none {
                partcounter.step()
                counter(page).update(1)
            }

            align(center + horizon)[
                #text(14pt)[
                    #strong([
                    Part 
                    #numbering("I", counter(heading).at(loc).first())
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
                        #numbering("1", chaptercounter.at(loc).first() + 1)
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
                    #numbering("1.1", chaptercounter.at(loc).first(), ..counter(heading).at(loc).slice(2))
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
    })

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
    
    par(justify: true)[#doc]
}
