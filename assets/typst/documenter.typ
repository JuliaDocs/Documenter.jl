// Import mitex for LaTeX math rendering
#import "@preview/mitex:0.2.6": *
#import "@preview/itemize:0.2.0" as el
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *

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
  compat: rgb("1db5c9"),
)
#let admonition-titles = (
  default: "Note",
  danger: "Danger",
  warning: "Warning",
  note: "Note",
  info: "Info",
  tip: "Tip",
  compat: "Compatibility",
)

// Font sizes
#let text-size = 11pt
#let code-size = 9pt
#let heading-size-title = 24pt
#let heading-size-part = 18pt
#let heading-size-chapter = 18pt
#let heading-size-part-label = 14pt
#let heading-size-chapter-label = 14pt
#let heading-size-section = 14pt
#let heading-size-subsection = 13pt
#let heading-size-subsubsection = 12pt
#let header-size = 10pt
#let admonition-title-size = 12pt
#let metadata-size = 12pt

#let code-font = ("JetBrains Mono", "DejaVu Sans Mono")

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
    #text(admonition-title-size, fill: white)[#strong(title)]
    #v(-0.5em)
    #rect(width: 100%, fill: bgcolor, inset: 10pt)[
      #children
    ]
  ]
}

#let extended_heading(level: 0, outlined: true, within-block: false, body) = {
  // Add pagebreak for level 1 and 2 headings, unless they are within a block (like admonition)
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
    let el_loc = el.location()

    let maybe_number = if el.numbering != none {
      if el.level == 1 {
        numbering("I", ..counter(heading).at(el_loc))
      } else if el.level == 2 {
        // Chapter counter: .at() returns value after step() (0,1,2...)
        // Display as 1,2,3... so add 1
        numbering("1", chaptercounter.at(el_loc).first() + 1)
      } else {
        numbering("1.1", ..chaptercounter.at(el_loc), ..counter(heading).at(el_loc).slice(2))
      }
      h(0.5em)
    }

    if indent {
      h(1em * (el.level - 1))
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
        },
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
  doc,
) = {
  set text(
    size: text-size,
  )

  set heading(numbering: "1.1")

  show: el.default-enum-list

  set list(
    marker: ([•], [--], [∗], [•], [--], [∗], [•], [--], [∗]),
    spacing: linespacing,
  )

  set page(
    header: context {
      let loc = here()

      // First page has no header
      if loc.page() <= 1 {
        return
      }

      // 1. Check if current page is a Part page (level 1 heading page)
      let parts_on_page = query(heading.where(level: 1)).filter(h => h.location().page() == loc.page())

      if parts_on_page.len() > 0 {
        return // Part pages don't show header
      }

      // 2. Check if current page is a Chapter first page (level 2 heading page)
      let chapters_on_page = query(heading.where(level: 2)).filter(h => h.location().page() == loc.page())

      if chapters_on_page.len() > 0 {
        return // Chapter first pages don't show header
      }

      // 3. Find the current effective chapter (level 2, both numbered and unnumbered)
      let all_chapters = query(heading.where(level: 2))

      // 4. Find the last chapter with page <= current page
      let current_chapter = none
      for ch in all_chapters {
        if ch.location().page() <= loc.page() {
          current_chapter = ch
        } else {
          break // Query results are in document order
        }
      }

      // 5. Display header if valid chapter found
      if current_chapter != none {
        align(center)[
          #text(header-size)[
            #if current_chapter.numbering != none {
              // Numbered chapter: show "CHAPTER X. TITLE"
              // .at() returns value after step(), add 1 for display
              let chapter_num = chaptercounter.at(current_chapter.location()).first() + 1
              [CHAPTER #numbering("1", chapter_num). ]
            }
            // Always show the title in uppercase
            #upper(current_chapter.body)
          ]
        ]
        line(length: 100%, stroke: 0.5pt)
      }
    },
    footer: context {
      let loc = here()

      // First page has no footer
      if loc.page() <= 1 {
        return
      }

      // Part pages don't show footer
      let parts_on_page = query(heading.where(level: 1)).filter(h => h.location().page() == loc.page())

      if parts_on_page.len() > 0 {
        return
      }

      // Show page number (automatically uses current numbering style)
      align(center)[
        #counter(page).display()
      ]
    },
  )

  // Set color for links
  show link: it => {
    // Internal links use label (<...>) or location
    // External links use string ("...")
    if type(it.dest) == label or type(it.dest) == location {
      text(fill: dark-blue)[#it]
    } else {
      text(fill: dark-purple)[#it]
    }
  }

  show: codly-init.with()
  codly(languages: codly-languages, number-format: none)
  show raw: set text(font: code-font)
  show raw.where(block: true): set text(size: code-size)

  show heading: it => context {
    let loc = here()
    if it.level == 1 {
      if partcounter.get().first() == 1 and it.numbering != none {
        partcounter.step()
        counter(page).update(1)
      }

      align(center + horizon)[
        #text(heading-size-part-label)[
          #strong([
            Part
            #numbering("I", counter(heading).get().first())
          ])] <__part__>
        #v(1em)
        #text(heading-size-part)[#strong(it.body)]
      ]
    } else if it.level == 2 {
      align(left + top)[
        #if it.numbering != none {
          // Get current value before stepping (for display)
          let chapter_display = chaptercounter.get().first() + 1
          chaptercounter.step()
          // Reset figure counter when entering a new chapter
          counter(figure.where(kind: image)).update(0)
          text(heading-size-chapter-label)[
            #strong([
              Chapter
              #numbering("1", chapter_display)
            ])]
          v(1em)
        }
        #text(heading-size-chapter)[#strong(it.body)] <__chapter__>
        #v(1em)
      ]
    } else {
      v(0.5em)
      if it.level == 3 {
        text(heading-size-section)[
          #strong([
            #numbering("1.1", chaptercounter.get().first(), ..counter(heading).get().slice(2))
            #h(1em)
            #it.body
          ])
        ]
      } else if it.level == 4 {
        text(heading-size-subsection)[#strong(it.body)]
      } else if it.level <= 6 {
        text(heading-size-subsubsection)[#strong(it.body)]
      } else {
        h(2em)
        text(heading-size-subsubsection)[#strong(it.body)]
      }
      v(0.5em)
    }
  }

  show list: set par(justify: false)

  // Custom quote styling
  show quote: it => {
    rect(
      width: 100%,
      fill: rgb("f8f8f8"),
      stroke: (left: 4pt + rgb("cccccc")),
      inset: (left: 15pt, right: 15pt, top: 10pt, bottom: 10pt),
      radius: (right: 3pt),
    )[
      #it.body
    ]
  }

  if title != none {
    // Front matter: Roman numerals, simplified footer
    set page(
      numbering: "i",
      footer: context {
        let loc = here()
        if loc.page() <= 1 { return }  // No footer on title page
        align(center)[#counter(page).display("i")]
      }
    )
    counter(page).update(1)
    
    align(center + horizon)[
      #text(heading-size-title)[#strong[#title]]
      #v(2em)
      #if authors != none {
        text(metadata-size)[#strong[#authors]]
        v(2em)
      }
      #text(metadata-size)[#date]
      #pagebreak()
    ]
    
    outline(depth: 3, indent: true)
    pagebreak()
  } else {
    outline(depth: 3, indent: true)
    pagebreak()
  }

  // Main matter: Arabic numerals, restore header and footer
  set page(
    numbering: "1",
    footer: context {
      let loc = here()
      // Part pages don't show footer
      let parts_on_page = query(heading.where(level: 1)).filter(h => h.location().page() == loc.page())
      if parts_on_page.len() > 0 { return }
      // Show page number
      align(center)[#counter(page).display("1")]
    }
  )
  counter(page).update(1)

  // Configure figure numbering to include chapter number
  set figure(numbering: num => context {
    let chapter_num = chaptercounter.get().first()
    // Format as "Chapter.Figure" (e.g., "1.1", "2.3")
    numbering("1.1", chapter_num, num)
  })

  // Don't wrap doc in par() - it causes all content to be in one paragraph
  set par(justify: true)
  doc
}
