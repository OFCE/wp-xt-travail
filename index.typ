// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



/// TITLE PAGE template partial
#import "@preview/icu-datetime:0.1.2": fmt-datetime, fmt-date

///// STYLE ELEMENTS FOR TYPST TEMPLATES


  // Colour definition

  #let grey0 =  rgb("#030303")
  #let grey1 =  rgb("#6B6B6B")
  #let grey2 =  rgb("#A6A6A6")
  #let grey3 =  rgb("#D6D6D6")
  #let scpored = rgb("#e6142d")
  #let scpodarkred = rgb("#770C19")
  #let colourtype = rgb("#EEC900")
  #let ife1 = rgb("#7D0000")
  #let ife2 = rgb("#21606E")
  #let ifegrey = rgb("#DDDBDB")

  // Font definition
  #let main_title_font = "Arimo"
  #let serif_font = "Merriweather"

 // Callout settings
  
#let callout(
body: [],
title: "Callout",
background_color: none,
icon: none,
icon_color: none,
body_background_color: white) = {
  let _bg = rgb("#faf0f3")
  let _ic = rgb("#faf0f3")
  let _bbg =  rgb("#faf0f3")
  block(
    breakable: true,
    fill: _bg,
    stroke: (paint: _ic, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      breakable: true,
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        breakable: true,
        fill: _bg,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(_ic, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          breakable: true,
          inset: 1pt,
          width: 100%,
          block(breakable: true, fill: _bbg, width: 100%, inset: 8pt, align(left, body)))
      }
    )
}


#let title-page(
  title:[],
  subtitle:[],
  authors: none, email:[],
  first_publish: none,
  abstract: none, year: none,
  number:[],
  draft: false,
  language: "fr",
  body) = {

  let marge = 3.5cm
  let ph = 29.7cm // page height for a4
  let pw = 21.0cm // page width for a4
  let logo_column = 4cm
  let lc_space = 0.75cm
  let line_x = -0.5cm + (logo_column - marge) + lc_space*2

  let grey0 =  rgb("#030303")
  let grey1 =  rgb("#6B6B6B")
  let grey2 =  rgb("#A6A6A6")
  let grey3 =  rgb("#D6D6D6")
  let scpored = rgb("#e6142d")
  let scpodarkred = rgb("#770C19")
  let colourtype = rgb("#EEC900")
  let ife1 = rgb("#7D0000")
  let ife2 = rgb("#21606E")
  let ifegrey = rgb("#DDDBDB")

  // Font definition
  let main_title_font = "Arimo"
  let serif_font = "Merriweather"

// Author block

let nrows = calc.min(authors.len(), 3)

let authorblock()={
if authors != none {
    grid(
      rows: nrows,
      row-gutter: 0.5em,
      ..authors.map(author =>
          align(left)[
            #text(author.name, weight: "bold",size: 11pt), #text(author.affiliation,style:"italic",size: 11pt)
          ]
      )
    )

  }

}




  // Date formatting



  let main_date = if first_publish != none {
  first_publish.text
  } else {
  none }


 let pretty_date =   if main_date != none {

    let date_decomp = main_date.split("-")
    let year_fp = int(date_decomp.at(0))
    let month_fp = int(date_decomp.at(1))
    let day_fp = int(date_decomp.at(2))
    let date_formatted = datetime(year: year_fp, month: month_fp, day: day_fp)

    fmt-date(date_formatted, length: "long", locale: language)

  }

  // Année affichée : on privilégie `annee` (yaml) ; à défaut on extrait
  // l'année de la date de première publication.
  let display_year = if year != none {
    year
  } else if main_date != none {
    main_date.split("-").at(0)
  } else {
    none
  }

    // Page formatting

  set page(margin: (top: marge, rest: marge))

  set text(font: main_title_font, size: 14pt)
  set heading(numbering: "1.1.1")

  // place(top + right, text(blue,"+")) // position tester

  /////// 1. logo position and line

  place(top + left, dx: -marge+lc_space,dy:-2cm,
        image("/_extensions/ofce/ofce/img/ofce_m.png", width: logo_column*0.7)
        )

  place(bottom + left, dx: -marge+lc_space,dy: 2cm,
        image("/_extensions/ofce/ofce/img/sciencespo.png", width: logo_column*0.7)
      )
  place(left,
        line(start: (line_x, 0cm), end: (line_x,  ph - 2*marge),
  stroke: (thickness: 1.25pt, paint: grey1)))

  //// 2. Title Position



  place(dx: 2cm,dy: 4cm,
    box(width: 13cm,
      align(horizon + left)[
        #text(size: 24pt, title, fill: ife2, weight: "bold", font: serif_font)
        #v(1em)
        #text(subtitle,fill: grey1)
        #v(2em)

        #authorblock()

        // #text(date_decomp, size: 14pt)


      ]/// end align
    ) /// end box,
  )





  //// 3. Publishing date And Issue number

  if not draft {
  place(top+right ,dy:-2cm,dx: marge ,
        square(fill: ife1, size: 2cm,align(center+horizon,text(fill: white,size: 1.5cm,number)))
      )

  if display_year != none {
  place(top+right ,dy:0cm,dx: marge ,
        text(fill: ife1, size: 0.9cm,text(display_year))
      )
  }
  } else {
  place(top+right ,dy:-2cm,dx: marge ,
        box(fill: ife1, inset: 8pt, radius: 2pt,
          align(center+horizon,text(fill: white,size: 0.9cm, weight: "bold","BROUILLON")))
      )
  }

  place(top + right, dx:+1.25cm,dy:-1.5cm, align(horizon,text(fill: gray ,size:1cm,weight: "bold", font: serif_font,style:"italic","Document de travail")))


  place(bottom + right, dx: 1.5cm,

  [
    #text({
      if(first_publish != none){
        [Première publication : ]
        }
        }, weight: "semibold", size: 10pt

        )
    #text({
      if(first_publish != none){
        [ #pretty_date \ ]
        }
        }, size: 10pt

        )


  ]

  )
  //// 4. Abstract

  place(bottom, dx: 2*lc_space + line_x, dy: -1*line_x,
  clearance: 4cm,
    box(fill: grey3, baseline: 100%,width: 13cm,inset: 1em,
      text(style: "italic",abstract,size: 10pt)
      )
    )

  //// 5. Internal cover page
  pagebreak()
  set page(fill: none, margin: auto)





  /// start
  //pagebreak()
  body
}


#import "@preview/icu-datetime:0.1.2": fmt-datetime, fmt-date


///// STYLE ELEMENTS FOR TYPST TEMPLATES

  // Colour definition

  // #let grey0 =  rgb("#030303")
  // #let grey1 =  rgb("#6B6B6B")
  // #let grey2 =  rgb("#A6A6A6")
  // #let grey3 =  rgb("#D6D6D6")
  // #let scpored = rgb("#e6142d")
  // #let scpodarkred = rgb("#770C19")
  // #let colourtype = rgb("#EEC900")

  // // Font definition
  // #let main_title_font = "Open sans"
  // #let serif_font = "Open sans"


/// CORE TEXT


#let preprint(
  title: none,
  subtitle: none,
  running-head: none,
  authors: none,
  affiliations: none,
  abstract: none,
  keywords: none,
  authornote: none,
  citation: none,
  first_publish: none,
  leading: 0.6em,
  spacing: 1em,
  first-line-indent: 0cm,
  linkcolor: rgb(0, 0, 0),
  paper: "a4",
  language:"fr",
  region: "US",
  font: ("Times", "Times New Roman", "Arial"),
  fontsize: 11pt,
  section-numbering: none,
  toc: false,
  toc_title: "contents",
  toc_depth: none,
  toc_indent: 1.5em,
  number: none,
  draft: false,
  bibliography-title: "Références",
  bibliography-style: "apa",
  cols: 1,
  col-gutter: 4.2%,
  doc,
) = {

  /* Document settings */

  let grey0 =  rgb("#030303")
  let grey1 =  rgb("#6B6B6B")
  let grey2 =  rgb("#A6A6A6")
  let grey3 =  rgb("#D6D6D6")
  let scpored = rgb("#e6142d")
  let scpodarkred = rgb("#770C19")
  let colourtype = rgb("#EEC900")

  // Font definition
  let main_title_font = "Arimo"
  let serif_font = "Merriweather"


  // Date formatting

    let main_date = if first_publish != none {
  first_publish.text
  } else {
  none }


 let pretty_date =   if main_date != none {

    let date_decomp = main_date.split("-")
    let year_fp = int(date_decomp.at(0))
    let month_fp = int(date_decomp.at(1))
    let day_fp = int(date_decomp.at(2))
    let date_formatted = datetime(year: year_fp, month: month_fp, day: day_fp)

    fmt-date(date_formatted, length: "long", locale: language)

  }



  // Set link and cite colors
  show link: set text(fill: linkcolor)
  show cite: set text(fill: linkcolor)

 show figure.where(kind: "quarto-float-apptbl"): set block(breakable: true)
 show figure.where(kind: table): set block(breakable: true)

  // Allow custom title for bibliography section
  set bibliography(title: bibliography-title, style: bibliography-style, )

  // Format author strings here, so can use in author note
  let author_strings = ()
  if authors != none {
    for a in authors{
      let author_string = [#a.name]
      author_strings.push(author_string)
    }

  }

  // Page settings (including headers & footers)
  set page(
    paper: paper,
    margin: (inside: 3.5cm, outside: 2.5cm, rest: 3cm),
    numbering: "1",
    header-ascent: 50%,
    header:

        // Page 3
              context if here().page() == 3 {

          grid(
          columns: (1fr, 1fr),
          align(left+ bottom)[#text(if draft [Document de travail OFCE — brouillon] else [Document de travail OFCE nº #number\ publié le #pretty_date], style: "italic")],
          align(right + bottom)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ]

          )


        } else {

          if(calc.even(here().page())){

            grid(
            columns: (1fr, 1fr),
            align(left + bottom)[#counter(page).display()],
            align(right + bottom)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ]

          )

          } else {
          grid(
            columns: (1fr, 1fr),
            align(left)[#image("/_extensions/ofce/ofce/img/ofce.png", width: 1cm) ],
            align(right)[#counter(page).display()]
          )


          }

          // Page >1 header has running head and page number

        line(start: (0cm, -0.5em), end: (15cm,  -0.5em),
  stroke: (thickness: 0.25pt, paint: grey1))
        }
    ,
    footer-descent: 24pt,
    footer:

              context if here().page() == 3 {

        } else {

        }

  )

  // Paragraph settings
  set par(
    justify: true,
    leading: leading,
    first-line-indent: first-line-indent,
    spacing: spacing
  )


  // Text settings
  set text(
    region: region,
    font: font,
    size: fontsize
  )

  // Headers
  set heading(
    numbering: section-numbering
  )
  // Level 1 headers
  show heading.where(
    level: 1
  ): it => block(width: 100%, below: 1em, above: 1.25em)[
    #set text(size: fontsize*1.3, weight: "bold", font: serif_font)
    #it
  ]
  // Level 2 headers
  show heading.where(
    level: 2
  ): it => block(width: 100%, below: 1em, above: 1.25em)[
    #set text(size: fontsize*1.05)
    #it
  ]
  // Level 3 headers
  show heading.where(
    level: 3
  ): it => block(width: 100%, below: 0.8em, above: 1.2em)[
    #set text(size: fontsize, style: "italic")
    #it
  ]
  // Level 4 headers are in paragraph
  show heading.where(
    level: 4
  ): it => box(
    inset: (top: 0em, bottom: 0em, left: 0em, right: 1em),
    text(size: 1em, weight: "bold", it)
  )
  // Level 5 headers are in paragraph
  show heading.where(
    level: 5
  ): it => box(
    inset: (top: 0em, bottom: 0em, left: 0em, right: 1em),
    text(size: 1em, weight: "bold", style: "italic", it)
  )


pagebreak()


  /* Content */



v(4cm)



text(title, size: 24pt, weight: "bold", font: serif_font)

if subtitle != none {
v(1em)
text(subtitle, size: 16pt, weight: "semibold")
}


v(1em)

text(author_strings.join(", ", last: " & "))

  // Separate content a bit from front matter
  v(4em)

  // Show document content with cols if specified
  if cols == 1 {
    doc
  } else {
    columns(
      cols,
      gutter: col-gutter,
      doc
    )
  }

v(4cm)


// text("Fin" , size: 14pt, weight: "bold")
}

// Remove gridlines from tables
#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)


#show: body => title-page(
  title: [Une part des salaires dans la VA élevée en 2025 en France],
  email: "mailto: student@youraddress.com",
  subtitle: [Comparaisons internationales de 30~ans de partage de la valeur ajoutée],  authors: (
          (
        name: [Xavier Timbeau],
        affiliation: [OFCE, Sciences Po Paris],
        email: [xavier.timbeau\@sciencespo.fr] ),
      
      ),
  abstract: [],
  year: [2025],
  number:[23],
  draft: false,

  first_publish: [2025-10-24],

  language: "fr",
  body
)

#show: doc => preprint(
  title: [Une part des salaires dans la VA élevée en 2025 en France],
  subtitle: [Comparaisons internationales de 30~ans de partage de la valeur ajoutée],
  number:[23],
  draft: false,
  authors: (
          (
        name: [Xavier Timbeau],
        affiliation: [OFCE, Sciences Po Paris],
        email: [xavier.timbeau\@sciencespo.fr] ),
      
      ),
  first_publish: [2025-10-24],
  citation: (
    type: "article-journal",
    container-title: "Document de travail de l'OFCE",
    doi: "",
    url: "https:/\/www.offce.fr/wp/2025/23"
  ),
  language: "fr",
  abstract: [On explore différentes façons de calculer la part des salaires dans la valeur ajoutée. Le concept privilégié est celui de la part des salaires #emph[corrigés de la non salarisation par le revenu mixte] dans la valeur ajoutée #emph[nette de la consommation de capital fixe] des branches #emph[marchandes hors services immobiliers]. Il fait apparaître une position singulière de la France où la part des salaires est plus élevé et s'est accrue de façon importante. Le calcul de rendement net d'impôts du capital productif confirme ce diagnostic particulièrement préoccupant pour le tissu productif français. Outre les explications habituelles de la hausse de la part des salaries dans la valeur ajoutée, nous ajoutons l'évaporation de la valeur ajoutée par l'optimisation fiscale. L'ensemble des éléments présentés est reproductible à partir des codes fournis sur le dépôt associé.],
  paper: "a4",
  font: ("Arimo",),
  section-numbering: "1.1.a",
  doc,
)

= Du partage de la VA au partage des richesses
<du-partage-de-la-va-au-partage-des-richesses>
L'analyse du partage de la valeur ajoutée (#ref(<fig-psal>, supplement: [graphique])) est au cœur des débats sur la redistribution des richesses (voir notamment Hurlin et Portier (1996), Timbeau (2002), Cotis (2009), Husson (2010), Askenazy, Cette et Sylvain (2012), Piton (2019), Pak, Pionnier et Schwellnus (2019), Cette, Koehl et Philippon (2019), Timbeau (2025), Gendre et Thommen (2025)).

Le processus de productif engage d'un côté des travailleurs, qu'ils soient salariés ou non, et des apporteurs de capitaux (ou capitalistes), qu'ils soient investisseurs actionnaires, détenteurs de titres de dette ou prêteurs. La nature des contrats reliant chacun de ces intervenants au partage de la richesse produite est très diverse. Certains sont à la fois travailleurs et actionnaires --- un entrepreneur cumule les deux rôles, D'autres sont dans des positions radicalement différentes, comme entre un programmeur de l'IA ou un #emph[trader] dont les bonus peuvent être considérables et un agent de maintenance au contrat précaire. Bien que les frontières ne soient pas aussi nettes que ce que l'on peut souhaiter, ce qu'on appelle communément la part des salaires dans la valeur ajoutée est un indicateur central dans la mesure du conflit de répartition entre le travail et le capital, ou plus directement les travailleurs et les capitalistes.

Nous explorons ici la construction de cet indicateur afin qu'il réponde le mieux possible à la question posée, à savoir le confilt de répartition. Cela nous amène à privilégier la part des salaires #emph[augmentés de la rémunération des non salariés par leur revenu mixte] dans la valeur ajoutée #emph[nette de la consommation de capital fixe] en se limitant #emph[aux branches marchandes hors immobilier].

Il apparaît que la part des salaires dans la valeur ajoutée en France est croissante depuis 30~ans (#ref(<fig-psal>, supplement: [graphique])), est la plus haute quand à la compare à 5 grands Etats membre de la zone Euro. Ce résultat contraste avec le consensus qui s'est établit depuis le rapport Cotis \(Cotis, 2009) et confirmé récemment par Cette, Koehl et Philippon (2019), Pak, Pionnier et Schwellnus (2019) ou Gendre et Thommen (2025) que la part des salaires en France est constante depuis la fin des années 1980.

#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Part des salaires dans la VA
]
, 
label: 
<fig-psal>
, 
position: 
top
, 
supplement: 
"Graphique"
, 
subcapnumbering: 
"(a)"
, 
[
#figure([
#box(image("index_files/figure-typst/fig-psal-2-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaires dans la VA Hors immo. (-L)
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psal-2>


]
)
Nous détaillons en les discutant dans la suite de ce document les effets des corrections appliquées et des choix de mesure retenus, ainsi que la différence entre les mesures dérivées des comptes de branche ou des comptes d'agents (ou de secteurs institutionnels), puisque nous nous limitons aux informations de la comptabilité nationale que nous tâchons d'exploiter le plus possible. Nous comparons systématiquement les indicateurs entre pays, au prix d'un échantillon de pays restreints et d'approximations indispensables. Ces éléments mis bout à bout sont un peu fastidieux, mais ils s'avèrent assez importants pour comprendre en quoi on peut préférer une mesure à une autre. Ils vont également à l'encontre de certaines intuitions ou a priori, particulièrement lorsqu'on les compare d'un pays à l'autre.

Nous explorons également les conséquences en matière de taux de profit (part des profits nets dans la valeur ajoutée) ou rendement du capital (profits nets divisés par les actifs), avec là aussi des résultats frappants en ce qui concerne la France.

Le code permettant de reproduire les graphiques et les tableaux est disponible dans un #link("https://github.com/xtimbeau/travail")[dépôt github] afin d'assurer la transparence et la reproductibilité des éléments produits.

== Du bon concept de part des salaires
<du-bon-concept-de-part-des-salaires>
Trois points sont importants pour disposer du bon concept (voir Reis (2022) pour une revue de littérature sur ce point) :

- #strong[Corriger des non salariés et leur imputer une masse salariale]. La correction habituelle consiste à affecter aux non salariés le même salaire que les salariés (généralement de la même branche) ; c'est ainsi que traitent la question Cette, Koehl et Philippon (2019) et Gendre et Thommen (2025). Nous procédons à cette correction (appelée #emph[correction par les effectifs]) aux 21 branches de la NACE rev. 2 niveau 1 mais nous proposons ici une alternative en utilisant la mesure du revenu mixte (dite #emph[correction par le revenu mixte]), parce que l'affectation d'un salarie égal aux non salariés et aux salariés par branches conduit à imputer une masse salariale supérieure au revenu mixte des non salariés#footnote[Merci à E. Aurissergues pour m'avoir pointé cette anomalie.], voire de dépasser la valeur ajoutée de la branche. En France, le revenu mixte (des non-salariés) est passé de 30% de la masse salariale (autant pour le ratio des effectifs) au début des années 1970 à un peu moins de 10% (presque 15% pour les effectifs) en 2024. Malheureusement, le revenu mixte par branche n'est pas diffusé systématiquement par les Etats membres de l'UE et nous utilisons une méthode hybride, qui impute suivant les effectifs relatifs de non salariés le revenu mixte agrégé. Ces corrections modifient significativement la part des salaires dans la valeur ajoutée, suivant la méthode, parce que non seulement la part des non salariés et de leur revenu mixte varie dans le temps, de façon différente par un effet de structure (moins d'agriculteurs) et de nature (les non salariés sont moins rémunérés aujourd'hui), de façon différente par pays (#ref(<fig-psalcnc>, supplement: [graphique]) et voir l'#link("annexes.html#a4")[annexe 4] consacrée à ce point).

- #strong[Limiter l'analyse au champ pertinent]. Il est plus simple de calculer la part des salaires au niveau le plus agrégé, mais ce champ inclut les branches non marchandes dans lesquelles la notion de prix et donc de valeur ajoutée est conventionnelle (la valeur ajoutée est estimée au coût des facteurs). Parmi les branches marchandes, la branches des services immobiliers est problématique parce qu'elle prend en compte la valeur ajoutée des ménages au travers des services immobiliers qui sont pour part auto produit (les loyers imputés aux propriétaires) et pour part produits par les ménages pour d'autres ménages (les propriétaires bailleurs). Suivant les pays ou les périodes, le nombre de propriétaires occupants peut être très différent (Cette, Koehl et Philippon (2019) fait ce point). Mais le vrai problème est que le partage de la valeur ajoutée entre salariés et producteur n'a ici pas de sens dans le cas d'un loyer imputé ou d'un propriétaire bailleur et que le niveau de loyer représente plutôt le conflit de répartition d'une ressource plus ou moins rare entre propriétaires et locataires. La consommation de services immobiliers par les ménages représentait en France en 2024 un peu moins de 300~milliards d'euros soit approximativement 18% de la valeur ajoutée brute hors services immobilier. La notion privilégiée est donc celle de partage de la valeur ajoutée dans les branches marchandes hors services immobiliers ou, de façon plus précise, en enlevant de la valeur ajoutée marchande la branche « services immobiliers (L) » (#link("annexes.html#a3")[annexe 3], #ref(<fig-structbranche>, supplement: [graphique])). Omettre les services immobiliers pose cependant un problème, parce qu'on exclu de l'analyse les loyers payés par les entreprises pour leurs locaux et constitue bien un élément de coût. La comptabilité nationale n'évalue pas un loyer implicite pour les entreprises -- sans doute à raison -- ce qui induit un biais spatial et temporel dans les consommations intermédiaires retenues.

- #strong[Utiliser la notion de valeur ajoutée nette] (de la consommation de capital fixe (CCF)) plutôt que brute. Rappelons que la valeur ajoutée nette est construite en ôtant de la valeur ajoutée brute la consommation de capital fixe. La CFF est évaluée par des tables de mortalité à l'inventaire permanent des investissements productifs (actifs produits) non financiers (i.e.~les investissements physiques mais aussi ceux en logiciels ou en base de données ainsi que les investissements intangibles comme les marques). En traitant les investissements comme une consommation intermédiaire mesurée par leur amortissement physique ou fiscal, on est plus proche de la réalité du processus productif (voir Sicsic (2018)). Lorsque le taux de dépréciation du capital varie, par des changement dans les tables de mortalité, des changements dans la composition du capital ou des changements dans la structure par branche de l'économie, la CCF rapportée à la valeur ajoutée varie et modifie donc la perception des évolutions du partage de la valeur ajoutée. La notion de valeur ajoutée nette est meilleure pour des comparaisons dans l'espace ou dans le temps. Comme pour la correction pour les non salariés, la prise en compte de la valeur ajoutée nette modifie dans le temps et dans l'espace la part des salaires dans la valeur ajoutée (#ref(<fig-psalnetbrut>, supplement: [graphique])). Ce point est signalé par Gendre et Thommen (2025), mais les auteurs ont préféré le concept de valeur ajoutée brute pour des raisons de comparabilité entre études -- au détriment de la comparabilité dans le temps et dans l'espace.

== Le partage entre travailleurs et capitalistes : une définition
<le-partage-entre-travailleurs-et-capitalistes-une-définition>
Le concept que nous privilégions, la part des salaires #emph[corrigé de la non salarisation par le revenu mixte] dans la valeur ajoutée #emph[nette des branches marchandes hors services immobiliers], est défini par l'équation ci-après.

Pour chaque branche $D 1_b$ est la masse salariale chargée, $B 1 G_b$ la valeur ajoutée brute, $P 51 C_b$ la $C C F_b$, les trois notions en euros aux prix courants et $n s_b\/s a l_b$ le ratio revenu mixte à la masse salariale par branche et $D 29 - D 39$ les autres impôts de production nets de subventions.

La valeur ajoutée est donc aux prix de base, c'est-à-dire net des impôts et subventions à la production ou encore hors taxes, cette notion étant étendue aux autres impôts et subventions. Les branches exclues sont les branches L (services immobiliers) et O (administration publique, défense et sécurité), P (éducation), Q (santé humaine et travail social)#footnote[Cette, Koehl et Philippon (2019) utilisent une définition plus large des branches non marchande en incluant les branches R, T et U.] :

$ s = frac(sum_(b eq.not L O P Q) D 1_b *\(1 + n s_b\/s a l_b\), sum_(b eq.not L O P Q) B 1 G_b - P 51 C_b -\(D 29_b - D 39_b\)) $

Cette définition de la valeur ajoutée, au prix de marché, après impôt et suventions et de la consommation de capital fixe, permet d'analyser le partage entre salariés d'un côté et propriétaires ou financeurs des entreprises, puisque la somme de la part des salaires et de la part des profits nets est égal à 1. D'un côté du partage, on trouve les salariés et les non salariés, une catégorie hétérogène mais dont on retient le trait principal de tirer son revenu de son travail, par différentes formes de contrats, et de l'autre ceux qui financent l'entreprise, c'est-à-dire à la fois les banques, les marchés financiers pour le financement non bancaire et les actionnaires. Il est possible de faire la distinction entre actionnaires et autres financeurs (à travers la dette nette des entreprises et les inétrêts nets versés), mais cette distinction n'est pas robuste pour les branches et est factice (par exemple, le #emph[private equity] rend difficile l'imputation de la dette).

Pour exclure de ce partage complètement les impôts, il conviendrait de retirer de la valeur ajoutée l'impôt sur les sociétés. C'est en effet, par exemple, une partie de la valeur ajoutée qu'un investisseur étranger ne peut percevoir. En revanche pour un investisseur résident, la taxation des dividendes (via le prélèvement forfaitaire unique, PFU) et la taxation par l'impôt sur les sociétés conduit à un taux marginal (à peu près) comparable à l'impôt sur le revenu et dans ce cas le traitement serait plutôt identique pour les revenus d'activité (soumis à l'IR) et les revenus de la propriétés (IS+PFU). Pour autant, les taux marginaux ne sont pas comparables et n'intègrent que partiellement la taxe inflationniste sur la capital détenu ou les gains en capital (ou plus-values), latents jusqu'à leur réalisation, mais qui échappent assez facilement à la taxation \(Allègre, Plane et Timbeau, 2012).

En tout état de cause, la comptabilité nationale ne permet pas (encore) de distinguer finement l'impôt sur les sociétés ($D 5$) par branche et l'imputation à un sous ensemble des branches est périlleux : il y a dans les branches non marchandes ou dans la branche L « services immobiliers » des entités soumises à l'IS et il est difficile de produire un numérateur pertinent incluant $D 51$. Nous avons fait une telle imputation grossièrement #ref(<fig-rp>, supplement: [graphique]), qui est à considérer avec prudence.

== La France a une part des salaires au plus haut
<la-france-a-une-part-des-salaires-au-plus-haut>
La part des salaires dans la valeur ajoutée nette corrigé par le revenu mixte est croissante en France (#ref(<fig-psal>, supplement: [graphique]), #ref(<tbl-psal>, supplement: [tableau]) et #ref(<tbl-evolpsal>, supplement: [tableau])) (de 5,7~points de 1998 le point bas à 2024, le dernier point non extrapolé) alors qu'elle est stable (Italie) ou décroissante (Espagne, Allemagne, Pays-Bas et Belgique). Elle atteint en France le niveau le plus élevé des pays sélectionnés (87% pour les branches marchandes hors services immobiliers), pour autant que l'on puisse comparer entre pays et ce pour les différents concepts que l'on peut envisager (#ref(<tbl-psal>, supplement: [tableau])).

Ce résultat contraste avec les évaluations récentes de Cette, Koehl et Philippon (2019) et Gendre et Thommen (2025) qui concluent à une stabilité de la part des salaires dans la valeur ajoutée autour de ce qu'ils concluent être une valeur d'équilibre. Cette (relative) stabilité se retrouve lorsqu'on inclue les services immobiliers et que l'on considère la valeur ajoutée brute plutôt que la valeur ajoutée nette (voir #link("annexes.html#a3")[annexe 3]).

En revanche, depuis 2018, la part des salaires dans la valeur ajoutée apparaît assez stable en France.

La part des salaires dans la valeur ajoutée est la plus basse aux Pays-Bas, la décroissance des années 1995 à 2008 semblant s'être interrompue après la crise financière. L'Italie affiche une variabilité temporelle importante, avec un pic de la part des salaires dans la valeur ajoutée en 2013 faisant suite à une brusque hausse dès 2008. En Belgique, au contraire, la baisse de la part des salaires coïncide avec la crise financière de 2008.

#figure([
], caption: figure.caption(
position: top, 
[
Part des salaires en 2024
]), 
kind: "quarto-float-tbl", 
supplement: "Tableau", 
)
<tbl-psal>


La séquence allant de la crise sanitaire (2020) à la forte inflation énergétique (2022 à 2024, suite à la hausse des prix de l'énergie consécutive à l'agression de l'Ukraine par la Russie) a eu des effets variables suivant les pays. Dans beaucoup de pays, la part des salaires a augmenté franchement, les salariés ne subissant pas complètement l'effet des mesures de confinement. C'est moins le cas en France et en Belgique, où la socialisation des salaires par l'activité partielle a pu limiter la hausse des coûts salariaux --- et avec des comptabilisations sans doute nuancées suivant les pays et les dispositifs. La période d'inflation élevée a fortement réduit la part des salaires en Allemagne, en Italie ou aux Pays-Bas. Dans les autres pays, les salaires semblent s'être ajustés plus vite (voir aussi le #ref(<fig-salaires>, supplement: [graphique])).

#figure([
], caption: figure.caption(
position: top, 
[
Evolution de la part des salaires
]), 
kind: "quarto-float-tbl", 
supplement: "Tableau", 
)
<tbl-evolpsal>


Différents éléments théoriques peuvent être avancés, comme les effets du progrès techniques, la combinaison (substitution) du travail et du capital ou la formation des salaires ou des taux d'intérêt (voir #ref(<tip-theorie>, supplement: [encadré])).

#figure([
#block[
#callout(
body: 
[
Cette, Koehl et Philippon (2019) proposent une modélisation simple des principaux déterminants du partage de la valeur ajoutée sur la base d'une fonction de production. Reis (2022) étend l'analyse en équilibre néo-keynésien.

Dans ces approches, l'évolution de part des salaires dans la valeur ajoutée dépend de la fonction de production agrégée (ce qui suppose qu'elle existe). Si l'élasticité de substitution entre le capital et la travail est unitaire alors on s'attend à ce que le partage soit indépendant du prix relatif du travail et du capital. La part des salaires est alors uniquement déterminée par la forme de la fonction de production et devrait converger dans tous les pays vers une valeur semblable, par diffusion de la technologie. Une structure de l'économie par branche différente peut cependant se traduire par des parts différentes d'un pays à l'autre.

L'élasticité estimée généralement, au moins à moyen terme, est sensiblement inférieure à 1, en tout cas sur données macroéconomique \(Cette, Koehl et Philippon, 2019). Cela implique qu'une hausse du prix du travail relativement par au capital se traduit par une hausse de la part du travail dans la valeur ajoutée -- la réciproque étant bien entendu vraie si c'est le capital qui est relativement plus cher. Cela peut conduire à des variations plus persistantes de la part des salaires dans la valeur ajoutée (ce qu'on appelle le #emph[wage push]), mais ces variations doivent reproduire celles des prix relatifs.

Nous ajoutons un élément d'explication supplémentaire aux variations de la part des salaires dans la valeur ajoutée : l'#emph[évaporation] de la valeur ajoutée par transfert de celle-ci vers un autre pays ou une autre branche, principalement pour des raisons d'optimisation fiscale. Si le ratio salaire sur VA est employé dans la négociation salariale, il est possible que cette évaporation soit organisée pour l'avantage qu'elle procurerait dans la négociation.

La théorie de la régulation \(Boyer #emph[et al.], 2023~; Boyer et Saillard, 2002) propose un angle radicalement différent, mais dans lequel la part des salaires (augmentée de la rémunération des non salariés!) dans la valeur ajoutée joue un rôle central et les modes de négociation salariale et des contractualisations de l'activité productive sont au cœur du régime de production.

]
, 
title: 
[Les déterminants théoriques de la part des salaires dans la valeur ajoutée]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
none
, 
body_background_color: 
white
)
]
], caption: figure.caption(
position: top, 
[
]), 
kind: "quarto-callout-Astuce", 
supplement: "Tip", 
numbering: callout-numbering, 
)
<tip-theorie>


#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Part des salaires dans la VA nette 1995 et 2025
]
, 
label: 
<fig-psaleu>
, 
position: 
top
, 
supplement: 
"Graphique"
, 
subcapnumbering: 
"(a)"
, 
[
#figure([
#box(image("index_files/figure-typst/fig-psaleu-1-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaires dans la VA nette 1995 et 2025 VA nette
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psaleu-1>


]
)
== Le rendement du capital productif au plus bas en France
<le-rendement-du-capital-productif-au-plus-bas-en-france>
La construction d'un taux de rendement du capital productif est sans doute assez fragile parce qu'il faut ajouter à l'évaluation du partage de la valeur ajoutée une estimation des impôts payés (notamment l'impôt sur les sociétés) et une évaluation du stock de capital (voir #ref(<sec-profits>, supplement: [section]) pour la méthode). En utilisant les données de stock de capital productif, le diagnostic présenté sur le #ref(<fig-psal>, supplement: [graphique]) est confirmé par le #ref(<fig-rp>, supplement: [graphique]).

Le choix du champ est assez important pour conserver une cohérence entre numérateur et le dénominateur. Pour le champ hors immobilier, le profit net et le stock de capital excluent toutes les activités immobilières parce que dans la plupart des pays (Allemagne, France, Italie) seule la branche immobilière détient des actifs de type logement ($N 111 N$ dans la nomenclature de la NACE rev. 2). Dans quelques pays, une part minoritaire de la valeur du stock de logements est détenue par d'autres branches (F, K, O, Q, R, S en Espagne (15%) ou en Belgique (0,5%); K au Pays-Bas (5%)) que la branche services immobiliers --- ce qui suggère que la séparation branche/secteur a été interprétée assez librement d'un pays à l'autre.

La France occupe une position singulière avec un rendement du capital productif particulièrement faible (#ref(<tbl-rend>, supplement: [tableau])). Il est ainsi équivalent à celui mesuré en Espagne (pour l'année 2023) avant IS, mais en tenant compte d'un IS effectif plus élevé, le rendement après IS est plus nettement plus bas en France.

#figure([
], caption: figure.caption(
position: top, 
[
Rendement du capital productif en 2023 ou 2024
]), 
kind: "quarto-float-tbl", 
supplement: "Tableau", 
)
<tbl-rend>


Le rendement du capital productif est décroissant en France depuis le début des années 2000 (#ref(<fig-rp>, supplement: [graphique])) alors qu'il est constant dans beaucoup de pays ou même croissant aux Pays-Bas. Les politiques de l'offre successives, depuis le choc fiscal de Nicolas Sarkozy, le pacte pour la croissance, la compétitivité et l'emploi de François Hollande en 2012 ou encore les politiques d'attractivité, en particulier fiscales, engagées par Emmanuel Macron depuis 2017 n'ont apparemment pas changé grand chose à cette dégradation continue. Tout au plus, on peut y associer la (relative) stabilisation du taux de rendement net en France (#ref(<fig-rp>, supplement: [graphique])) à partir de 2017.

En Allemagne, le rendement est stable depuis le milieu des années 2000, sans doute en lien avec les réformes Hartz à partir de 2003 --- bien que le redressement du rendement a commencé avant. Le rebond à partir de 2020 en Italie est spectaculaire.

Une explication possible de la dégradation du rendement du capital productif est à chercher du côté de son fort accroissement aux Pays-Bas --- malgré un poids de l'IS de plus en plus lourd dans ce pays --- sous l'effet du déplacement de la base fiscale à l'intérieur de l'Europe comme l'analysent Tørsløv, Wier et Zucman (2022) ou encore d'un déplacement vers la branche des services immobiliers pour bénéficier de la fiscalité immobilière (#ref(<sec-immobilier>, supplement: [section])).

Le recours à des prix de transfert et la localisation de certains actifs dans des pays européens à la fiscalité attractive pourrait donc être à l'origine d'une part des salaires élevée en France ou d'un rendement du capital productif faible#footnote[La localisation de la dette bancaire dans des filiales dans des pays qui dégrèvent la dette de la base fiscale impôt sur les sociétés peut modifier le bilan des entreprises mais ne joue pas, au contraire des prix de transfert, ni sur la valeur ajoutée résidente, ni sur le stock de capital productif (mais sur le bilan de l'entreprise filiale). Un phénomène similaire à l'évaporation de la valeur ajoutée vers un autre pays peut passer par le secteur immobilier (voir la #ref(<sec-immobilier>, supplement: [section])).]. Cette évaporation n'implique pas nécessairement, mais ne l'exclue pas non plus, la dégradation de la productivité des facteurs par un retard technologique, une formation insuffisante de la main d'œuvre, un manque d'infrastructure ou une spécialisation sectorielle dégradée.

#figure([
#box(image("index_files/figure-typst/fig-rp-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Rendement du capital productif (avant et après IS)
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-rp>


== Salaires réels et inflation
<salaires-réels-et-inflation>
L'évolution des salaries réels est un complément à celle du partage de la valeur ajoutée. Pour passer de l'un à l'autre, il faut non seulement prendre en compte les évolutions de la valeur ajoutée, mais aussi les effets de l'évolution du ratio prix à la consommation sur prix de valeur ajoutée.

On déflate la masse salariale (comptabilité nationale, comptes trimestriels) par les prix à la consommation. On utilise les masses salariales ($D 1$, dans #link("https://ec.europa.eu/eurostat/databrowser/view/NAMQ_10_A10/default/table?lang=en")[#NormalTok("namq_10_a10");]) par branches pour comparer branches (principalement) marchandes et (principalement) non marchandes divisées par l'emploi salarié (#link("https://ec.europa.eu/eurostat/databrowser/view/NAMQ_10_A10_E__custom_7475124/default/table?lang=en")[#NormalTok("namq_10_a10_e");]). Les prix sont les déflateurs de la consommation ($P 31\_S 14$ dans #link("https://ec.europa.eu/eurostat/databrowser/product/page/NAMQ_10_FCS")[#NormalTok("namq_10_fcs");]) chaînés (voir le code pour les détails).

On distingue 4 agrégations : l'ensemble des branches (ou l'ensemble de l'économie), les branches non marchandes, les branches marchandes et les branches marchandes hors immobilier.

#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Salaires réels en Europe
]
, 
label: 
<fig-salaires>
, 
position: 
top
, 
supplement: 
"Graphique"
, 
subcapnumbering: 
"(a)"
, 
[
#figure([
#box(image("index_files/figure-typst/fig-salaires-1-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Salaires réels en Europe avec cot.soc. employeur
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-salaires-1>


]
)
En Italie et en Espagne, la masse salariale dans les branches non marchandes est supérieures à celle des branches non marchandes. Aux Pays-Bas et en Allemagne il n'y a pas de différence notable. En France, elle est significativement plus basse. Notons que les branches non marchandes ne sont pas nécessairement de l'emploi public et ce dans des proportions variables suivant les pays. Dans tous les pays, la masse salariale des branches services immobiliers et (surtout) services financiers est plus élevée que la masse salariale dans les autres branches marchandes.

= Comptes de branches : que changent les concepts et le champ ?
<comptes-de-branches-que-changent-les-concepts-et-le-champ>
== Salariés et non salariés
<salariés-et-non-salariés>
On utilise les données de comptabilité nationale, en trimestriel, par branche (#link("https://ec.europa.eu/eurostat/databrowser/view/nasq_10_nf_tr/default/table?lang=en")[#NormalTok("nasq_10_nf_tr");]), ré-agrégées au niveau de l'ensemble de l'économie. Le passage par les comptes de branches permet de distinguer branches marchandes et non marchandes ou d'autres regroupements, comme l'exclusion des services immobiliers. Ce passage permet également de conduire la correction salariés non salariés au niveau des branches.

D'après l'INSEE, (voir le blog « #link("https://blog.insee.fr/combien-pese-l-industrie-en-france-et-en-allemagne/")[Combien pèse l'industrie en France et en Allemagne] », Larieu (2024)), tous les pays ne produisent pas une comptabilité de branche mais pour certains (notamment l'Allemagne) une comptabilité sectorielle. La différence tient aux entreprises qui produisent plusieurs produits (un constructeur automobile propose des services financiers pour l'achat des véhicules) et dont l'activité est imputé à différentes branches (industrie et services financiers) dans la comptabilité de branche alors que dans une comptabilité de secteur l'activité est versée dans le principal secteur (ou le secteur d'immatriculation de l'entreprise chapeau). Cette différence empêche normalement les comparaisons des comptes de branches entre pays, y compris à l'intérieur de l'Union Européenne. Cependant, pour comparer la part des salaries dans la valeur ajoutée sur des agrégats larges (branches marchandes par exemple), cette dérogation à la norme comptable n'est que modérément problématique : de toute façon, l'automobile et les services financiers sont agrégés et c'est la correction pour la masse salariale des non salariés qui peut être modifiée. Mais si la même délimitation est employée pour les salariés et les non salariés que pour l'activité, l'erreur est probablement minime.

La part des salaires est corrigée de la part des non salariés (données annuelles #link("https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64_e/default/table?lang=en")[#NormalTok("nama_10_a64_e");], extrapolées en maintenant le ratio salariés/non salariés à sa dernière valeur observée) en considérant que le salaire des non salariés est identique dans chaque branche à celui des salariés -- cette hypothèse, que nous appelons #emph[correction par les effectifs], sous estime probablement le salaire de certains des non salariés (notamment les professions libérales ou les artisans) et surestime celui d'autres indépendants (chauffeurs et livreurs des plateforme, auto-entrepreneurs du bâtiment) mais elle est difficile à lever. Le développement des plateformes et dans certains pays de statuts (sociaux, fiscaux) particuliers (les micro-entrepreneurs -- ou auto-entrepreneurs en France) a introduit une nouvelle « classe » de non salariés possiblement moins rémunérés et avec des durées du travail plus basses que le reste des indépendants. L'#link("annexes.html#4")[annexe 4] compile quelques éléments quantitatifs.

En revanche, dans la correction par les effectifs, on prend bien en compte que les non salariés de la branche agricole n'ont pas le même revenu que ceux de la branche « information et communication ». La décomposition employée est à 9 branches et on peut conduire la même correction à un niveau de désagrégation plus fin. Une alternative est employée en utilisant les données de revenu mixte. A défaut d'être totalement convaincante, du fait d'un manque de données diffusées, elle montre la complexité et l'importance de la correction pour le revenu des indépendants. Une solution aurait pu être de ne considérer que les entreprises (voir #ref(<sec-snff>, supplement: [section])) mais là aussi les différentes pratiques de comptabilité ne garantissent pas un traitement homogène d'un pays à l'autre et surtout occultent un pan important de l'économie (en Italie aujourd'hui ou en France dans le passé par exemple).

La masse salariale est rapportée soit à la valeur ajoutée brute ($B 1 G$), soit à la valeur ajoutée nette ($B 1 N = B 1 G - P 51 C$). Comme la consommation de capital fixe ($P 51 C$) n'est pas connue en trimestriel, elle est dérivée des comptes annuels en 21 branches (niveau 1 de la NACE rev. 2 #link("https://ec.europa.eu/eurostat/databrowser/view/nama_10_a64/default/table?lang=en")[#NormalTok("nama_10_a64");]), agrégée en 9 branches, puis extrapolée pour les années non connues (ici 2024 et 2025) en conservant un ratio constant dans la valeur ajouté brute. Le détail se trouve dans le code.

Les trois graphiques suivants illustrent les conséquences sur la mesure de la part des salaires suivant les différents concepts. Le #ref(<fig-psalcnc>, supplement: [graphique]) compare avec et sans correction pour les non salariés. Deux rubans sont affichés, l'un pour les branches marchandes hors services immobiliers et financiers et l'autre pour toutes les branches.

L'avantage des comptes de branches est une définition homogène pour chacun des pays. La branche immobilier est exclue parce qu'il est impossible de distinguer les entreprises des ménages propriétaires (les loyers imputés sont comptabilisés comme une valeur ajoutée des ménages).

Les données trimestrielles sont annualisées pour la lisibilité et pour simplifier le mélange de données annuelles et trimestrielles. Le point 2025 (la dernière année) est donc un acquis sur les trimestres observés de l'année (ici 2 ou 3 trimestres sur 4) susceptible de changer au fur et à mesure du temps. Il est possible en modifiant le code de produire un graphique trimestriel ou trimestriel lissé.

#figure([
#box(image("index_files/figure-typst/fig-psalcnc-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Correction pour la non salarisation, comptes de branches
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psalcnc>


La correction de la non salarisation, en imputant une masse salariale pour les entrepreneurs individuels à partir de la rémunération moyenne des salariés, augmente la part des salaires. La correction n'est pas constante dans le temps (c'est particulièrement fort pour la France) ni dans l'espace (la correction est très forte en Italie). La correction est plus importante lorsqu'on se limite aux branches marchandes hors services immobiliers et services financiers, sauf aux Pays-Bas.

Cette convention d'imputation d'un salaire aux non salariés est habituelle \(Askenazy, Cette et Sylvain, 2012~; Cette, Koehl et Philippon, 2019~; Cotis, 2009~; Gendre et Thommen, 2025~; Husson, 2010~; Pak, Pionnier et Schwellnus, 2019~; Reis, 2022~; Timbeau, 2002, 2025). Elle pose cependant un problème de cohérence avec le revenu mixte mesuré dans la comptabilité nationale.

Le revenu mixte est le revenu des entrepreneurs individuels, autoentrepreneurs et autres catégories d'indépendants. Il n'intègre pas l'activité des ménages en tant qu'employeurs (employés de maison) ou en tant que bailleur (loyers perçus ou imputés) qui sont comptabilisés dans l'excédent brut d'exploitation des ménages (S14). Le #ref(<tbl-mixte>, supplement: [tableau]) résume pour les 6 principaux pays analysés l'écart entre masse salariale imputée (en 2024) et revenu mixte.

#figure([
], caption: figure.caption(
position: top, 
[
Revenu mixte et masse salariale imputée aux non salariés
]), 
kind: "quarto-float-tbl", 
supplement: "Tableau", 
)
<tbl-mixte>


En France et en Belgique, la convention employée surestime visiblement la masse salariale que l'on peut imputer aux non salariés, puisqu'elle est supérieure au revenu mixte. En revanche, en Allemagne ou en Espagne, c'est l'inverse. Le cas Français est intéressant, parce que le ratio masse salariale imputée sur revenu mixte devient plus grand que 1 en 2013 et et augmente quelques années avant. Le régime d'autoentrepreneur introduit en 2008 peut expliquer cette dynamique en généralisant le nombre de non salariés ayant de faibles revenus et éventuellement étant salariés par ailleurs (voir l'#link("annexes.html#a4")[annexe 4] pour plus de détails).

On peut construire à partir du revenu mixte une correction alternative de la non salarisation en utilisant le revenu mixte -- en retenant 88% du revenu mixte lorsqu'on ne peut pas faire mieux#footnote[Le chiffre de 88% est établi à partir des comptes nationaux français qui permettent de calculer le ratio CCF sur revenu mixte pour les entrepreneurs individuels (secteur institutionnel S14AA). Pour la France nous utilisons le ratio calculé chaque année (qui varie entre 9,4% et 13,8% entre 1995 et 2024). Ce chiffre est plus faible que celui pour l'ensemble de l'économie marchande (de l'ordre de 20%, voir l'#link("annexes.html#a2")[annexe 2]), ce qui peut s'expliquer par le fait que les structures fortement capitalistiques (et avec une forte CCF) sont moins suceptibles d'être des indépedants, parce qu'il est nécessaire de les financer par une structure de capital à responsabilité limitée et faisant intervenir des actionnaires qui ne sont pas le seul dirigeant. Enfin, nous supposons que dans le cas des indépendants la part des profits est nulle et que la rémunération de l'indépendant est équivalente à un revenu d'activité, ce qui est conforme au traitement fiscal en général. Lorsque l'entrepreneur souhaite bénéficier d'une fiscalité différente sur les revenus d'activité et les revenus du capital, il est contraint de passer d'un régime d'indépendant à une structure juridique moins souple.], le reste pour approcher la CCF des indépendants -- et non le nombre de non salariés (correction par les effectifs) comme base de la correction.

#figure([
#box(image("index_files/figure-typst/fig-psalmixte-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Correction pour la non salarisation, effectifs ou revenu mixte, comptes de branches
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psalmixte>


La correction est assez différente pour la France et la Belgique, ce qui est conforme aux valeurs affichées dans le #ref(<tbl-mixte>, supplement: [tableau]). La hausse de la part des salaires apparaît moins importante que pour la correction par les effectifs. Au lieu d'une hausse de 11,3~points de pourcentage (branches marchandes hors immobilier, de 1998 à 2024, pour la France), elle n'est que de de 5,7~points. La comparaison avec les autres pays est donc un peu moins brutale que pour la correction par les effectifs, l'Allemagne ayant en 2023 une part des salaires dans la valeur ajoutée plus proche de celle de la France en suivant la correction par le revenu mixte, qui ré-hausse la part des salaires en Allemagne (voir aussi le #ref(<tbl-mixte>, supplement: [tableau])) -- à la réserve près que la correction est moins précise pour l'Allemagne puisque nous n'avons pas les données de revenu mixte par branche (méthode hybride en répartissant le revenu mixte agrégé au prorata des effectifs de non salariés par branche), contrairement à la France.

Cette correction respecte plus les données issues de la comptabilité nationale et est donc plus appropriée pour évaluer la part des revenus d'activité dans la valeur ajoutée. C'est la correction privilégiée dans ce document.

== Valeur ajoutée nette ou brute
<valeur-ajoutée-nette-ou-brute>
#figure([
#box(image("index_files/figure-typst/fig-psalnetbrut-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
VA Nette ou brute, comptes de branches
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psalnetbrut>


La notion de part des salaires dans la valeur ajoutée nette consiste à réduire le dénominateur (la valeur ajoutée) de la consommation de capital fixe. Cela augmente donc le ratio. Cependant, cette correction n'est pas constante dans le temps (comme en France, en Espagne ou en Belgique). Comme on peut le voir en #link("annexes.html#a3")[annexe 3], la variance entre les pays est plus basse pour la notion brute (non corrigé de la CCF) que nette. Pour les branches marchandes hors services immobiliers et services immobiliers, le classement entre pays est marginalement modifié, la Belgique ayant une part des salaires nette plus élevée que l'Allemagne, alors que sa part brute est plus faible qu'en Allemagne. Pour les autres pays, le classement est identique (La France a la part la plus haute et les Pays-Bas plus faible).

La mesure de la consommation de capital fixe n'est pas mise en avant par les comptables nationaux par crainte d'une mesure imprécise, bien qu'elle soit publiée. Les conventions comptables sont assez disparates d'un pays à l'autre, rendant la comparaison directe sans doute fragile \(Sicsic, 2018).

Les comptables nationaux français traitent par exemple les logiciels produits pour compte propre comme des investissements, ce qui n'est pas le cas dans d'autres pays, où elle est considérée comme une production de logiciel d'un côté et une consommation intermédiaire de l'autre (dans l'approche branche, on sépare les activités d'une entreprise selon les produits). Cela conduit à un stock de capital productif élevé mais également à une consommation de capital fixe importante. On pourrait considérer que l'évaluation de la CCF est conventionnelle, appliquant des tables de mortalité théoriques à des produits divers et donc reflétant mal la réalité.

Cependant, l'exemple du traitement des logiciels pour compte propre nous signale surtout que c'est l'évaluation de la valeur ajoutée brute qui est biaisée et qu'elle est difficilement comparable d'un pays à l'autre. La valeur ajoutée brute ressort plus élevée en France parce que des consommations intermédiaires ne sont pas comptabilisées dans la valeur ajoutée alors qu'elles le seraient dans d'autres pays. La valeur ajoutée nette corrige (presque complètement) ce problème : l'investissement des uns génère une CCF alors qu'il est compté comme CI par les autres. en régime permanent (le fux d'investissement brut est constant dans la VA, la dépréciation est constante dans le temps), quelque soit la mortalité appliquée à l'investissement les deux approches aboutissent au même résultat : la valeur ajoutée nette est alors moins biaisée par la convention de traitement des investissements et des consommations intermédiaires que la valeur ajoutée brute, du moins à un niveau d'agrégation suffisant (puisque l'imputation de la production à une branche ou une autre peut aussi différer).

En régime non permanent, c'est-à-dire de périodes où par exemple l'investissement en logiciel augmente pour transformer les pratiques productives, le biais des conventions investissement versus consommation intermédiaire peut être important. Seule une normalisation plus avancée des pratiques comptables peut résoudre ce problème.

Le biais des conventions joue sur le stock de capital mesuré et peut biaisé les calculs et les mesures présentées (#ref(<fig-rp>, supplement: [graphique])\; #ref(<tbl-rend>, supplement: [tableau])\; #ref(<fig-tprofitbranches>, supplement: [graphique])) de rendement du capital productif.

== Impact du changement de structure de l'économie
<impact-du-changement-de-structure-de-léconomie>
On peut décomposer le changement de la part des salaires dans la valeur ajoutée en un effet de structure en branche et un effet de changement de la part des salaires dans la valeur ajoutée dans chaque branche. Formellement la décomposition retenue s'écrit (où $w_(b\,t)$ est la part de VAN de la branche $b$ dans la valeur ajoutée nette de l'ensemble des branches considérées et $s_(b\,t)$ la part des salaires dans la branche $b$) :

$ s_t - sum w_(b\,1995) times s_(b\,1995) = sum w_(b\,1995) times\(s_(b\,t) - s_(b\,1995)\)\
+ sum\(w_(b\,t) - w_(b\,1995)\)times s_(b\,t) $

L'année 1995 est l'année de référence et le premier terme (de droite) s'interprète comme la part des salaires qui prévaudrait s'il n'y avait pas eu de changement de structure. Le #ref(<fig-structbranche>, supplement: [graphique]) représente ce terme ainsi que la part agrégée des salaires ($s_t$). L'effet de la structure par branche de l'économie (ici marchande hors services immobiliers produits par les ménages) est assez marginale. Les variations de la part des salaires sont bien celle des parts des salaires dans chaque secteur.

Il existe quelques exceptions à cette règle générale. A structure de branche inchangée, avec comme année de référence 1995, la part des salaires serait plus basse de 3,5~points de VA pour les Pays-Bas en 2025. En Allemagne ou en Belgique, le changement de structure des branches explique un petit peu de l'évolution à la hausse.

En revanche, la part des salaires serait légèrement supérieure en Italie à structure inchangée. Le pic de valeur ajoutée en 2013 est lié entièrement à la structure par branche, ce qui laisse supposer une rupture de série dans les comptes de branche en Italie.

#figure([
#box(image("index_files/figure-typst/fig-structbranche-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Structure par branche et part des salaires dans la VA
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-structbranche>


== Profits nets dans les comptes de branche
<sec-profits>
En utilisant d'une part la valeur ajoutée des branches marchandes hors services immobiliers produits par les ménages et la valeur des actifs productifs issue de la base des stocks de capital productif (#link("https://ec.europa.eu/eurostat/databrowser/view/NAMA_10_NFA_ST__custom_2046386/default/table?lang=en")[nama\_10\_nfa\_st]) sur le même champ (#emph[i.e.] en enlevant la sous branche Lm), on peut estimer un rendement du capital productif.

#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Rendements du capital, compte de branches
]
, 
label: 
<fig-tprofitbranches>
, 
position: 
top
, 
supplement: 
"Graphique"
, 
subcapnumbering: 
"(a)"
, 
[
#figure([
#box(image("index_files/figure-typst/fig-tprofitbranches-2-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Rendements du capital, compte de branches Hors services immobiliers (-L)
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-tprofitbranches-2>


]
)
Le rendement calculé sur le #ref(<fig-tprofitbranches>, supplement: [graphique]) diffère de celui du #ref(<fig-tprofitsnff>, supplement: [graphique]). La différence vient en partie de la difficulté à imputer l'impôt des sociétés aux seules entreprises des branches marchandes -- des entités légales dans les branches non marchandes peuvent être soumises à l'impôt sur les sociétés et de la valorisation des actifs#footnote[Une alternative serait de disposer de l'impôt sur les sociétés ($D 51$) par branche, mais le passage branche vers produit empêche de le faire simplement.]. Dans l'approche comptes d'agents (ou de secteurs institutionnels), on affecte la valeur nette résiduelle des entreprises au stock de capital. De plus, le stock de capital n'est pas dans l'approche du #ref(<fig-tprofitsnff>, supplement: [graphique]) limité au capital productif mais intègre également des actifs financiers qui n'ont pas de contrepartie physique parce qu'ils sont hors territoire français.

La France conserve une singularité marquée par la baisse continue du taux de profit au cours du temps. Le rendement apparent du capital est ainsi très bas, plus bas que dans tous les autres pays considérés où il est plutôt stable (l'Italie fait exception avec une forte volatilité). Cette singularité subsiste lorsqu'on utilise la correction de la non salarisation par le revenu mixte au lieu des comptes de branches (#ref(<fig-rpmixte>, supplement: [graphique])). La position de la France est un peu moins singulière, mais le diagnostic subsiste. L'écart avec l'Allemagne est significativement réduit dans cette configuration, puisqu'en 2023 le rendement du capital productif ressort à 8,2% en France contre 9,3% en Allemagne. L'écart avec les Pays-Bas subsiste presque entièrement (19,2% de rendement aux Pays-Bas).

#figure([
#box(image("index_files/figure-typst/fig-rpmixte-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Rendement du capital productif, correction de la non salarisation par les effectifs ou le revenu mixte
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-rpmixte>


Reis (2022) conclut que le rendement du capital productif est plutôt constant au cours du temps, pour les 20 dernières années. L'analyse présentée ici le contredit pour la France et possiblement d'autres pays. Les données utilisées ne sont pas les mêmes, puisqu'il utilise principalement AMECO et que l'analyse conduite ici exploite plus de profondeur dans les données de comptabilité nationale.

= Comptes d'agents ou de secteurs institutionnels : Entreprise non financières et financières
<sec-snff>
== Part des salaires dans la valeur ajoutée, comptes d'agents
<part-des-salaires-dans-la-valeur-ajoutée-comptes-dagents>
Les comptes d'agents (ou de secteurs institutionnels) permettent une analyse plus simple, parce qu'ils permettent de distinguer les seules entreprises non financières. Cela évite d'avoir à prendre en compte les non salariés, cela exclue les services immobiliers produits par les ménages. C'est donc une analyse sur un champ économique plus strict (au sens de la forme légale des entités considérées). La notion d'impôt sur les sociétés est aussi mieux définie et le stock de capital productif est mieux connu du fait de l'obligation légale de déclaration des comptes des entreprises. Cette méthode met de côté une part importante de l'activité, puisque les entités économiques qui ne sont pas des entités légales ne sont pas prises en compte.

Malheureusement, comme identifié par l'INSEE, la pratique des instituts nationaux européens n'est pas conforme à celle de l'INSEE. Par exemple, en Allemagne, le secteur S11 inclut les quasi-sociétés et les entrepreneurs individuels. La normalisation des concepts est par ailleurs peu probable dans le futur, puisqu'elle est liée aux pratiques administratives.

Comme pour les graphiques précédents, les données trimestrielles sont annualisées (pour éliminer la variabilité trimestrielle qui nuit à la lisibilité et qui n'a pas beaucoup de sens). En trait pointillé, on représente la part de la valeur ajoutée dans les branches marchandes hors immobilier et corrigée de la non salarisation pour mesurer la différence des concepts.

#figure([
#box(image("index_files/figure-typst/fig-s11psal-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaires dans la VA, SNF, comptes d'agents
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-s11psal>


#figure([
#box(image("index_files/figure-typst/fig-s1112psal-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaires dans la VA, SNF+SF, comptes d'agents
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-s1112psal>


== Profits nets et dividendes dans les comptes d'agents
<sec-profitagent>
Les comptes des sociétés non financières permettent d'examiner d'autres éléments du compte. On affiche ici le profit net sur la valeur ajoutée nette, et le taux de dividendes nets sur la valeur ajoutée nette.

Les profits nets sont définis comme la valeur ajoutée nette de la consommation de capital fixe moins la rémunération des salariés, moins les taxes nettes des subventions moins l'impôt sur les sociétés :

$ Pi = B 1 G - P 51 C - D 1 -\(D 29 - D 39\)- D 5 = B 2 N - D 5 $

Les dividendes sont la ligne $D 42$ nette de ce qui est payé et reçu par le secteur des sociétés non financières (SNF ou S11).

#figure([
#box(image("index_files/figure-typst/fig-profits-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Profits nets dans la VA, SNF, comptes d'agents
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-profits>


On peut rapporter ces notions aux éléments qui viennent du compte de capital. Le premier concept est le profit rapporté au stock de capital physique (tel que valorisé dans la comptabilité nationale, c'est-à-dire à la valeur de remplacement et au prix de marché). Malheureusement, à part la France, aucun pays dans notre échantillon ne diffuse ces données sur Eurostat.

On rapporte également à une notion financière, à savoir la valeur nette des actions au passif des comptes d'entreprises. Les conventions de valorisation des actions non cotées sont délicates et difficiles à suivre d'un pays à l'autre. On choisit ici d'augmenter ces actions de la valeur nette résiduelle des entreprises non financières ($B F 90$). On a donc :

$ r_(p r o d u c t i f) & = frac(Pi, N 1 N + N 2 N)\
r_(f i n a n c i e r) & = frac(Pi, F 51 + F 52 + B F 90) $

On obtient le graphe suivant :

#quarto_super(
kind: 
"quarto-float-fig"
, 
caption: 
[
Rendements du capital, compte de secteur
]
, 
label: 
<fig-tprofitsnff>
, 
position: 
top
, 
supplement: 
"Graphique"
, 
subcapnumbering: 
"(a)"
, 
[
#figure([
#box(image("index_files/figure-typst/fig-tprofitsnff-1-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Rendements du capital, compte de secteur SNF
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-tprofitsnff-1>


]
)
= Au delà de l'Europe et pour l'ensemble de l'économie
<au-delà-de-leurope-et-pour-lensemble-de-léconomie>
Il est possible d'utiliser des données de comptabilité nationale, au niveau de l'ensemble de l'économie (y compris donc les branches non marchandes et l'immobilier). La correction pour la non-salarisation est assurée par les données de l'#emph[Economic Outlook] (avec une trimestrialisation #emph[ad hoc]). Au lieu de la valeur ajoutée, on utilise le PIB, auquel on enlève la consommation de capital fixe (dans les données OCDE, il n'y a pas de données de CCF pour le Japon publiées). Le concept de part des salaires n'est donc pas tout à fait le même que dans les autres analyses.

On obtient le #ref(<fig-psaloecd>, supplement: [graphique]), qui rejoint ceux présentés, bien que l'agrégation à l'ensemble de l'économie écrase les évolutions.

#figure([
#box(image("index_files/figure-typst/fig-psaloecd-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaries dans le PIN, données SNA de l'OCDE
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-psaloecd>


En revanche, Eurostat a un programme de coopération (avec l'OCDE entre autres) pour intégrer les données dans le cadre de données d'Eurostat (sans que les méthodes ne soient parfaitement homogènes pour autant).

On utilise ces données (#link("https://ec.europa.eu/eurostat/databrowser/view/naidsa_10_nf_tr__custom_13241966/default/table?lang=en")[#NormalTok("naidsa_10_nf_tr");]) pour construire des indicateurs comparables en comparant des pays autres que ceux de la zone euro.

#figure([
#box(image("index_files/figure-typst/fig-tprofithze-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Part des salaires dans la valeur ajoutée, comptes de secteur, comparaisons internationales
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-tprofithze>


= Evaporation de la valeur ajoutée : la piste fiscale
<sec-immobilier>
Plusieurs explications peuvent être avancées à la dégradation du rendement du capital productif#footnote[On peut aussi mettre en cause la qualité des comptes nationaux et leur incapacité à apporter une information même bruitée sur la réalité des économies contemporaines. Cette explication est commode lorsqu'on a une théorie envers laquelles les « faits » comptables sont têtus. Nous partons du principe qu'on peut utiliser l'information des comptes nationaux bien qu'ils ne soient pas parfaits.] :

- une part des salaires dans la valeur ajoutée trop importante, ce que suggèrent les éléments présentés plus haut,

- une fonction de production agrégée spécifique qui implique une part de l'immobilier plus importante compte tenu de la structure et de la technologie de l'économie française. Alternativement, si les services immobiliers sont imparfaitement substituables (ce qui est probable) aux autres facteurs de production, un prix relatif plus élevé de ces services immobiliers peut conduire à une part plus importante des consommations intermédiaires (en valeur).

- une mauvaise évaluation de la valeur des actifs productifs conduisant à surestimer le stock de capital productif, par exemple en sous estimant la consommation de capital fixe. L'#link("annexes.html#a2")[annexe 2] tend à contredire cette idée, la CCF étant plutôt plus élevée en France qu'ailleurs et le taux de dépréciation (CCF sur actif) étant assez stable dans le temps.

- un mécanisme d'optimisation fiscale par des prix de transfert vers d'autres pays européens (ce qu'explorent Tørsløv, Wier et Zucman (2022)), en particulier les Pays-Bas, qui affichent un rendement élevé et croissant du capital productif, qui provoquerait une évaporation de la valeur ajoutée dans certains pays au profit d'autres,

- un autre mécanisme d'optimisation fiscale, par la séparation des activités productives et des locaux qui leur sont nécessaires. Les loyers sont alors un prix de transfert et permettraient de bénéficier de la fiscalité avantageuse de l'immobilier#footnote[Une recherche sur internet aboutit rapidement à des documents de ce type : #link("https://www.frenchfigures.com/blog/placement-immobilier-entreprise#:~:text=Optimisation%20de%20l%27Imp%C3%B4t%20sur%20les%20Soci%C3%A9t%C3%A9s&text=Les%20loyers%20vers%C3%A9s%20par%20votre%20entreprise%20%C3%A0%20la%20structure%20d%C3%A9tenant,patrimoine%20immobilier%20du%20risque%20entrepreneurial.")[Les fondamentaux de l'investissement immobilier professionnel]. Le principe est que les plus values immobilières sont moins taxées que les flux de revenus à terme.] et pourrait constituer un autre canal d'évaporation de la valeur ajoutée.

Nous explorons dans cette section cette dernière piste. La difficulté est que l'activité résidentielle, et sa partie auto-produite, sont intégrées dans la branche « services immobiliers ». A partir des données détaillées de consommation (base #link("https://ec.europa.eu/eurostat/databrowser/view/nama_10_cp18__custom_18526061/default/table")[#NormalTok("nama_10_cp18");]), on peut approximativement#footnote[En ne prenant en compte que la consommation, on manque l'investissement des ménages en services immobiliers, à savoir les frais de transaction et d'agence lors des ventes.] reconstituer ces parts. Le #ref(<tbl-households>, supplement: [tableau]) fait apparaître que la valeur ajoutée de la branche « services immobiliers (L) » est particulièrement importante en France et que la partie hors service de logement des ménages est aussi particulièrement élevée.

#figure([
], caption: figure.caption(
position: top, 
[
Part des loyers et des loyers imputés dans la valeur ajoutée marchande
]), 
kind: "quarto-float-tbl", 
supplement: "Tableau", 
)
<tbl-households>


Le #ref(<fig-ciLfr>, supplement: [graphique]), pour la France uniquement, caractérise l'évolution de la consommation en services immobiliers par le secteur productif hors services aux ménages. La hausse est continue depuis le début de la période d'observation (qui débute en 1978 sur le #ref(<fig-ciLfr>, supplement: [graphique])), et s'achève en 2006. Cette hausse de la part des consommations intermédiaires ne peut donc pas expliquer à elle seule les évolutions du rendement apparent du capital productif.

#figure([
#box(image("index_files/figure-typst/fig-ciLfr-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Consommations intermédiaires en services immobiliers, France
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-ciLfr>


- Le #ref(<fig-rendfr>, supplement: [graphique]) confirme cette idée, mais illustre l'ordre de grandeur que les services immobiliers pourraient avoir sur le rendement du capital. Les deux courbes présentées sont d'une part le rendement avant IS du capital productif des branches marchandes non immobilières et d'autre part le même rendement, mais en modifiant la valeur ajoutée des branches marchandes non immobilières en appliquant le ratio consommation intermédiaire en services immobiliers de 1980 (il était alors de 3,3%). Cela représente plus d'un point de rendement.

#figure([
#box(image("index_files/figure-typst/fig-rendfr-1.svg", width: 100.0%))
], caption: figure.caption(
position: top, 
[
Rendement du capital productif, sensibilité aux CI en services immobiliers, France
]), 
kind: "quarto-float-fig", 
supplement: "Graphique", 
)
<fig-rendfr>


#block[
]
#heading(level: 1, numbering: none)[Références]
<références>
#block[
#block[
Allègre G., Plane M., Timbeau X. (2012). «~#link("https://doi.org/10.3917/reof.122.0231")[Réformer la fiscalité du patrimoine~?]~», #emph[Revue de l'OFCE], #emph[n° 122], n° 3, p.~231‑261.

] <ref-allègre2012>
#block[
Askenazy P., Cette G., Sylvain A. (2012). «~#link("https://doi.org/10.3917/dec.asken.2012.01")[Le partage de la valeur ajoutée]~», #emph[Repères].

] <ref-askenazy2012>
#block[
Boyer R., Chanteau J.-P., Labrousse A., Lamarche T. (2023). #emph[#link("https://doi.org/10.3917/dunod.boyer.2023.01")[Théorie de la régulation. Un nouvel état des savoirs]], Dunod, Paris (Éco Sup).

] <ref-boyer2023>
#block[
Boyer R., Saillard Y. (2002). #emph[#link("https://doi.org/10.3917/dec.boyer.2002.01")[Théorie de la régulation, l'état des savoirs]], La Découverte, Paris (Recherches).

] <ref-boyer2002>
#block[
Cette G., Koehl L., Philippon T. (2019). «~#link("https://doi.org/10.24187/ecostat.2019.510t.1993")[La part du travail sur le long terme : un déclin ?]~», #emph[Economie et Statistique / Economics and Statistics], n° 510‑511‑512, p.~35‑51.

] <ref-cette2019>
#block[
Cotis J.-P. (2009). «~#link("https://www.vie-publique.fr/rapport/30455-partage-valeur-ajoutee-partage-profits-et-ecarts-de-remuneration")[Partage de la valeur ajoutée, partage des profits et écarts de rémunérations en France]~», Rapport pour la Présidence de la République Française.

] <ref-cotis2009>
#block[
Gendre C., Thommen Y. (2025). «~#link("https://www.tresor.economie.gouv.fr/Articles/b72e151f-ac09-47e6-92eb-30657fce5e46/files/9a8f51d9-a060-4547-8852-b630858d7565")[Le partage de la richesse produite en France entre le travail et le capital]~», #emph[Trésor-Éco], n° 363.

] <ref-tresor2025>
#block[
Hurlin C., Portier F. (1996). «~#link("https://doi.org/10.3406/ecop.1996.5809")[Le partage de la valeur ajoutée dans le cycle]~», #emph[Économie & prévision], #emph[125], n° 4, p.~73‑85.

] <ref-hurlin1996>
#block[
Husson M. (2010). «~#link("https://doi.org/10.3917/rdli.064.0047")[Le partage de la valeur ajoutée en Europe]~», #emph[La Revue de l'Ires], #emph[n° 64], n° 1, p.~47‑91.

] <ref-husson2010>
#block[
Larieu S. (2024). «~#link("https://blog.insee.fr/combien-pese-l-industrie-en-france-et-en-allemagne/)")[Quel est vraiment le poids de l'industrie en France et en Allemagne ?]~», #emph[Le Blog de l'INSEE].

] <ref-larieu2024>
#block[
Pak M., Pionnier P.-A., Schwellnus C. (2019). «~#link("https://doi.org/10.24187/ecostat.2019.510t.1993")[La part du travail sur le long terme : un déclin ?]~», #emph[Economie et Statistique / Economics and Statistics], n° 510‑511‑512, p.~17‑34.

] <ref-pak2019>
#block[
Piton S. (2019). «~#link("https://doi.org/10.3917/rce.024.0131")[7. Le partage de la valeur ajoutée~n'a pas encore dévoilé tous ses mystères]~», #emph[Regards croisés sur l'économie], #emph[n° 24], n° 1, p.~131‑140.

] <ref-piton2019>
#block[
Reis R. (2022). «~#link("https://personal.lse.ac.uk/reisr/papers/99-ampf.pdf")[Which r-star, public bonds or private investment? Measurement and policy implications.]~»,.

] <ref-reis2022>
#block[
Sicsic P. (2018). «~#link("https://www.banque-france.fr/fr/publications-et-statistiques/publications/une-vision-apres-depreciation-du-compte-des-societes-non")[Une vision après dépréciation du compte des sociétés non financières]~», #emph[Bloc-notes Eco, Banque de France].

] <ref-sicsic2018>
#block[
Timbeau X. (2002). «~#link("https://doi.org/10.3917/reof.080.0063")[Le partage de la valeur ajoutée en France]~», #emph[Revue de l'OFCE], #emph[80], n° 1, p.~63.

] <ref-timbeau2002>
#block[
Timbeau X. (2025). «~#link("https://shs.cairn.info/revue-l-economie-politique-2025-1-page-64?lang=fr")[Quelles marges de manœuvre pour revaloriser le travail ?]~», #emph[Economie Politique], #emph[105], n° 1, p.~64‑75.

] <ref-timbeau2025>
#block[
Tørsløv T., Wier L., Zucman G. (2022). «~#link("https://doi.org/10.1093/restud/rdac049")[The Missing Profits of Nations]~», #emph[The Review of Economic Studies], #emph[90], n° 3, p.~1499‑1534.

] <ref-tørsløv2022>
] <refs>
#heading(level: 1, numbering: none)[Suppléments]
<fappfig-psalcompote>
6 annexes sont accessibles en ligne à l'adresse #link("https://xtimbeau.github.io/travail/") :

- annexe 1 : #link("https://xtimbeau.github.io/travail/annexes.html#a1")[Domaine des données],
- annexe 2 : #link("https://xtimbeau.github.io/travail/annexes.html#a2")[CCF],
- annexe 3 : #link("https://xtimbeau.github.io/travail/annexes.html#a3")[Comparaisons entre pays],
- annexe 4 : #link("https://xtimbeau.github.io/travail/annexes.html#a4")[Rémunération des non salariés],
- annexe 5 : #link("https://xtimbeau.github.io/travail/annexes.html#a5")[CN2020 et CN2014 pour la France],
- annexe 6 : #link("https://xtimbeau.github.io/travail/annexes.html#a6")[Rendement du capital productif en France de 1978 à 2024]

Un #link("https://xtimbeau.github.io/travail/NEWS.html")[historique des principales modifications] renseigne les différentes versions du document.

#heading(level: 1, outlined: false, numbering: none)[Nombre de mots]
<nombre-de-mots>
Il y a 7328 mots dans ce document (hors code, graphiques, tableaux et bibliographie).
