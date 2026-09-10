library(knitr)
opts_chunk$set(
  fig.pos="H",
  out.extra="",
  dev="svg",
  dev.args = list(bg = "transparent"),
  out.width="100%",
  fig.showtext=TRUE,
  message = FALSE,
  warning = FALSE,
  echo = FALSE,
  error = TRUE)

systemfonts::add_fonts(system.file("fonts", "OpenSans", "OpenSans-Regular.ttf", package="ofce"))

library(tidyverse)
library(ofce)
library(ggiraph)
library(gt)
library(readxl)
library(scales)
library(glue)
library(patchwork)
library(lubridate)
library(quarto)
library(conflicted)
library(countrycode)
library(marquee)
library(ofceweb)

options(
  ofce.base_size = 12,
  ofce.background_color = "transparent",
  ofce.marquee = TRUE,
  ofce.caption.ofce = FALSE,
  ofce.caption.wrap = 0,
  ofce.source_data.src_in = "file",
  sourcoise.grow_cache = Inf,
  ofce.source_data.force_exec = FALSE,
  ofce.output_extension = "xlsx",
  ofce.output_prefix = "va-xt-")
showtext::showtext_opts(dpi = 120)
showtext::showtext_auto()


options(cli.ignore_unknown_rstudio_theme = TRUE)
tooltip_css  <-
  "font-family:Open Sans;
  background-color:snow;
  border-radius:5px;
  border-color:gray;
  border-style:solid;
  border-width:0.5px;
  font-size:9pt;
  padding:4px;
  box-shadow: 2px 2px 2px gray;
  r:20px;"

milliards <- function(x, n_signif = 3L) {
  stringr::str_c(
    format(
      x,
      digits = n_signif,
      big.mark = " ",
      decimal.mark = ","),
    " milliards d'euros")
}

if(.Platform$OS.type=="windows")
  Sys.setlocale(locale = "fr_FR.utf8") else
    Sys.setlocale(locale = "fr_FR")


ccsummer <- function(n=4) PrettyCols::prettycols("Summer", n=n)
ccjoy <- function(n=4) PrettyCols::prettycols("Joyful", n=n)

bluish <- ccjoy()[1]
redish <- ccjoy()[2]
yelish <- ccsummer()[2]
greenish <- ccsummer()[4]
darkgreenish <- ccsummer()[3]
darkbluish <- ccjoy()[4]

lbl <- function(x, format=NULL) {
  if(is.null(format))
    if(is.null(dim(x)))
      fmt <- ifelse(max(stringr::str_length(x))==2, "eurostat", "iso3c")
    else
      fmt <- ifelse(max(stringr::str_length(x[,1]))==2, "eurostat", "iso3c")
  else
    fmt <- format
  if(is.null(dim(x)))
    return(countrycode(x, fmt, "country.name.fr"))
  x |>
    mutate(across(1, ~countrycode(.x, fmt, "country.name.fr")))
}

# vrai si la sortie est typst (quarto ne definit pas knitr::is_typst_output)
is_typst_output <- function() isTRUE(knitr::pandoc_to("typst"))

# les colonnes de drapeaux et de nanoplots sont des SVG en ligne : elles ne
# survivent ni en latex ni en typst, on les masque dans les deux cas
cols_hide_pdf <- function(tbl, col) {
  if(knitr::is_latex_output() || is_typst_output())
    return(gt::cols_hide(data = tbl, columns = {{ col }} ))
  return(tbl)
}

tableau.font.size <- 12

# gt ne transmet a typst que les largeurs de colonnes exprimees en pourcentage :
# les px sont perdus dans la conversion html -> pandoc -> typst, toutes les
# colonnes deviennent "auto" et le tableau est etire sur toute la largeur du
# texte par la note de bas de tableau (ofce_caption), qui occupe une cellule
# sur toute la largeur. En typst, la somme des pourcentages des colonnes fait
# la largeur du tableau : on repartit typst_width entre les colonnes visibles,
# proportionnellement aux largeurs deja demandees par cols_width() (a parts
# egales si aucune ne l'est). Sans effet hors typst : en html les px passes a
# cols_width() fonctionnent deja.
largeur_typst <- function(data, typst_width) {

  if(is.null(typst_width) || !is_typst_output()) return(data)

  bh <- data[["_boxhead"]]
  visible <- bh$type %in% c("default", "stub")
  vars <- bh$var[visible]
  if(length(vars) == 0) return(data)

  px <- vapply(bh$column_width[visible], function(x) {
    x <- as.character(unlist(x))
    if(length(x) == 0) NA_real_ else suppressWarnings(as.numeric(sub("px$", "", x[[1]])))
  }, numeric(1))
  if(all(is.na(px))) px <- rep(1, length(px)) else px[is.na(px)] <- mean(px, na.rm = TRUE)

  pct <- round(typst_width * px / sum(px), 2)
  formules <- lapply(seq_along(vars), function(i)
    stats::as.formula(sprintf("`%s` ~ gt::pct(%s)", vars[i], pct[i])))

  rlang::inject(gt::cols_width(data, !!!formules))
}

# typst_width : largeur du tableau en typst, en % de la largeur du texte
my_tab_options <- function(data, ..., typst_width = NULL) {
  tbl <- tab_options(data,
              footnotes.font.size = "90%",
              source_notes.font.size = "95%",
              # en typst, desactiver le traitement quarto fait passer la table
              # en html brut, que pandoc supprime : le tableau disparait
              quarto.disable_processing = !is_typst_output(),
              table.font.size = tableau.font.size,
              table_body.hlines.style = "none",
              column_labels.padding = 3,
              data_row.padding = 3,
              footnotes.multiline = FALSE,
              footnotes.padding = 5,
              source_notes.padding =  2,
              table.border.bottom.style = "none",
              table.background.color = "transparent",
              row_group.padding = 3) |>
    opt_footnote_marks("letters") |>
    tab_options(...)

  largeur_typst(tbl, typst_width)
}

conflicted::conflicts_prefer(dplyr::filter, .quiet = TRUE)
conflicted::conflicts_prefer(dplyr::select, .quiet = TRUE)
conflicted::conflicts_prefer(dplyr::lag, .quiet = TRUE)
conflicted::conflicts_prefer(lubridate::year, .quiet = TRUE)
conflicted::conflicts_prefer(lubridate::month, .quiet = TRUE)
conflicted::conflicts_prefer(dplyr::first, .quiet = TRUE)
conflicted::conflicts_prefer(dplyr::last, .quiet = TRUE)
conflicted::conflicts_prefer(dplyr::between, .quiet = TRUE)
conflicted::conflicts_prefer(lubridate::quarter, .quiet = TRUE)

ggplot2::set_theme(
  theme_ofce(
    marquee=TRUE,
    axis.line.y = element_blank(),
    legend.position = "bottom",
    legend.justification = "center",
    panel.grid = element_line(color = "grey95")
  ))

if(knitr::is_html_output())
  update_theme(text = element_text(size = 10)) else
    update_theme(text = element_text(size = 8))
