// Import mitex for LaTeX math rendering
#import "@preview/mitex:0.2.6": *
#import "@preview/itemize:0.2.0" as el
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *

#let deep-merge-pair(dict1, dict2) = {
  let final = (:) // Start with empty dictionary
  // First copy all keys from dict1
  for (k, v) in dict1 {
    final.insert(k, v)
  }
  // Then merge dict2, recursively for nested dictionaries
  for (k, v) in dict2 {
    if (k in final) and (type(v) == dictionary) and (type(final.at(k)) == dictionary) {
      // Both are dictionaries, merge recursively
      final.insert(k, deep-merge-pair(final.at(k), v))
    } else {
      // Override with dict2's value
      final.insert(k, v)
    }
  }
  final
}

#let deep-merge(..args) = {
  let dicts = args.pos()
  if dicts.len() == 0 {
    return (:) // Empty dictionary if no arguments
  }
  let final = dicts.first()
  // Start from second dictionary to avoid duplicating first
  for i in range(1, dicts.len()) {
    final = deep-merge-pair(final, dicts.at(i))
  }
  final
}

// Default configuration dictionary
#let default-config = (
  // Colors
  light-blue: rgb("6b85dd"),
  dark-blue: rgb("4266d5"),
  light-red: rgb("d66661"),
  dark-red: rgb("c93d39"),
  light-green: rgb("6bab5b"),
  dark-green: rgb("3b972e"),
  light-purple: rgb("aa7dc0"),
  dark-purple: rgb("945bb0"),
  codeblock-background: rgb("f6f6f6"),
  codeblock-border: rgb("e6e6e6"),
  // Admonition colors and titles
  admonition-colors: (
    default: rgb("363636"),
    danger: rgb("da0b00"),
    warning: rgb("ffdd57"),
    note: rgb("209cee"),
    info: rgb("209cee"),
    tip: rgb("22c35b"),
    compat: rgb("1db5c9"),
  ),
  admonition-titles: (
    default: "Note",
    danger: "Danger",
    warning: "Warning",
    note: "Note",
    info: "Info",
    tip: "Tip",
    compat: "Compatibility",
  ),
  // Font sizes
  text-size: 11pt,
  code-size: 9pt,
  heading-size-title: 24pt,
  heading-size-part: 18pt,
  heading-size-chapter: 18pt,
  heading-size-part-label: 14pt,
  heading-size-chapter-label: 14pt,
  heading-size-section: 14pt,
  heading-size-subsection: 13pt,
  heading-size-subsubsection: 12pt,
  header-size: 10pt,
  admonition-title-size: 12pt,
  metadata-size: 12pt,
  // Fonts
  text-font: ("Inter", "DejaVu Sans"),
  code-font: ("JetBrains Mono", "DejaVu Sans Mono"),
  // Spacing and layout
  outline-number-spacing: 0.5em,
  outline-indent-step: 1em,
  outline-part-spacing: 0.5em,
  outline-filler-spacing: 10pt,
  outline-line-spacing: -0.2em,
  // Admonition styling
  admonition-title-inset: (left: 1em, right: 5pt, top: 5pt, bottom: 5pt),
  admonition-title-radius: (top: 5pt),
  admonition-title-color: white,
  admonition-content-inset: 10pt,
  admonition-content-radius: (bottom: 5pt),
  // Table styling
  table-stroke-width: 0.5pt,
  table-stroke-color: rgb("cccccc"),
  table-inset: 8pt,
  // Quote styling
  quote-background: rgb("f8f8f8"),
  quote-border-color: rgb("cccccc"),
  quote-border-width: 4pt,
  quote-inset: (left: 15pt, right: 15pt, top: 10pt, bottom: 10pt),
  quote-radius: (right: 3pt),
  // Header styling
  header-line-stroke: 0.5pt,
)
#let config = default-config

// Use state to store runtime configuration that can be accessed by helper functions
#let config-state = state("documenter-config", default-config)
#let partcounter = counter("part")
#let chaptercounter = counter("chapter")

#let ceil(len, unit: 4pt) = calc.ceil(len / unit) * unit

#let admonition(type: "info", title: none, children) = context {
  let cfg = config-state.get()
  let color = cfg.admonition-colors.at(type)
  let bgcolor = color.lighten(50%)
  let adm-title = if title == none {
    cfg.admonition-titles.at(type)
  } else {
    title
  }

  // Title bar: non-breakable, zero spacing below
  block(
    width: 100%,
    breakable: false,
    fill: color,
    inset: cfg.admonition-title-inset,
    radius: cfg.admonition-title-radius,
    below: 0pt,
  )[
    #text(cfg.admonition-title-size, fill: cfg.admonition-title-color)[#strong(adm-title)]
  ]

  // Content area: breakable, zero spacing above
  block(
    width: 100%,
    breakable: true,
    fill: bgcolor,
    inset: cfg.admonition-content-inset,
    radius: cfg.admonition-content-radius,
    above: 0pt,
  )[
    #children
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
  let cfg = config-state.get()
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
      h(cfg.outline-number-spacing)
    }

    if indent {
      h(cfg.outline-indent-step * (el.level - 1))
    }

    if el.level == 1 {
      v(cfg.outline-part-spacing, weak: true)
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
      box(width: 1fr, h(cfg.outline-filler-spacing) + box(width: 1fr) + h(cfg.outline-filler-spacing))
    } else {
      box(width: 1fr, h(cfg.outline-filler-spacing) + box(width: 1fr, repeat[.]) + h(cfg.outline-filler-spacing))
    }

    // Page number
    let page_number = counter(page).at(el_loc).first()

    link(el_loc, if el.level == 1 {
      strong(str(page_number))
    } else {
      str(page_number)
    })

    linebreak()
    v(cfg.outline-line-spacing)
  }
}

#let documenter(
  title: none,
  date: none,
  version: none,
  authors: none,
  julia-version: none,
  linespacing: 1em,
  config: config, // Accept config parameter, default to global config
  doc,
) = {
  // Set config state at the start so helper functions can access it
  let cfg = deep-merge(default-config, config)
  config-state.update(cfg)

  set text(
    size: cfg.text-size,
    font: cfg.text-font,
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
          #text(cfg.header-size)[
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
        line(length: 100%, stroke: cfg.header-line-stroke)
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
      text(fill: cfg.dark-blue)[#it]
    } else {
      text(fill: cfg.dark-purple)[#it]
    }
  }

  show: codly-init.with()
  codly(
    languages: codly-languages,
    number-format: none,
    zebra-fill: none,
    inset: 5pt,
    fill: cfg.codeblock-background,
    stroke: 1pt + cfg.codeblock-border,
  )
  show raw: set text(font: cfg.code-font)
  show raw.where(block: true): set text(size: cfg.code-size)

  // Configure table styling for better readability
  set table(
    stroke: cfg.table-stroke-width + cfg.table-stroke-color,
    inset: cfg.table-inset,
  )
  // Enable text wrapping in table cells (inspired by LaTeX's tabulary package)
  show table.cell: it => {
    // Optimize line breaking and enable hyphenation for long words
    set par(justify: false, linebreaks: "optimized")
    set text(hyphenate: true, lang: "en", overhang: false)
    // Allow long words (>10 chars) to break by inserting zero-width spaces
    // This works for both regular text and link text, keeping links clickable
    show regex("\w{10,}"): it => {
      it.text.codepoints().join(sym.zws)
    }
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
        #text(cfg.heading-size-part-label)[
          #strong([
            Part
            #numbering("I", counter(heading).get().first())
          ])] <__part__>
        #v(1em)
        #text(cfg.heading-size-part)[#strong(it.body)]
      ]
    } else if it.level == 2 {
      align(left + top)[
        #if it.numbering != none {
          // Get current value before stepping (for display)
          let chapter_display = chaptercounter.get().first() + 1
          chaptercounter.step()
          // Reset figure counter when entering a new chapter
          counter(figure.where(kind: image)).update(0)
          text(cfg.heading-size-chapter-label)[
            #strong([
              Chapter
              #numbering("1", chapter_display)
            ])]
          v(1em)
        }
        #text(cfg.heading-size-chapter)[#strong(it.body)] <__chapter__>
        #v(1em)
      ]
    } else {
      v(0.5em)
      if it.level == 3 {
        text(cfg.heading-size-section)[
          #strong([
            #numbering("1.1", chaptercounter.get().first(), ..counter(heading).get().slice(2))
            #h(1em)
            #it.body
          ])
        ]
      } else if it.level == 4 {
        text(cfg.heading-size-subsection)[#strong(it.body)]
      } else if it.level <= 6 {
        text(cfg.heading-size-subsubsection)[#strong(it.body)]
      } else {
        h(2em)
        text(cfg.heading-size-subsubsection)[#strong(it.body)]
      }
      v(0.5em)
    }
  }

  show list: set par(justify: false)

  // Custom quote styling
  show quote: it => {
    rect(
      width: 100%,
      fill: cfg.quote-background,
      stroke: (left: cfg.quote-border-width + cfg.quote-border-color),
      inset: cfg.quote-inset,
      radius: cfg.quote-radius,
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
        if loc.page() <= 1 { return } // No footer on title page
        align(center)[#counter(page).display("i")]
      },
    )
    counter(page).update(1)

    align(center + horizon)[
      #text(cfg.heading-size-title)[#strong[#title]]
      #v(2em)
      #if authors != none {
        text(cfg.metadata-size)[#strong[#authors]]
        v(2em)
      }
      #text(cfg.metadata-size)[#date]
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
    },
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
