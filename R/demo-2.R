pacman::p_load(
  dplyr,
  tidyr,
  stringr,
  readr,
  openssl,
  igraph
)

source("R/foundation.R")
source("R/programs.R")

# Real WordPress extraction snapshots
historical_program_terms <- read_csv(
  "/mnt/muw/programs-terms.csv",
  show_col_types = FALSE
) |>
  filter(parent_term_id != 0)

in_scope_program_terms <- read_csv(
  "/mnt/muw/in_scope_program_terms.csv",
  show_col_types = FALSE
)

# WordPress -> compatibility layer
compat <- prepare_wp_program_compat(
  historical_program_terms = historical_program_terms,
  in_scope_program_terms = in_scope_program_terms
)

compat_programs <- compat$compat_programs
compat_program_terms <- compat$compat_program_terms

# Compatibility layer -> Salsa-shaped rows
programs <- build_programs(
  compat_programs,
  compat_program_terms
)

program_texts <- build_program_texts(
  compat_programs
)

program_term_map <- build_program_term_map(
  compat_program_terms
)

# Pipeline totals
tibble(
  stage = c(
    "Historical WP program terms",
    "In-scope WP terms",
    "Logical programs",
    "Historical aliases retained",
    "Localized program texts"
  ),
  rows = c(
    nrow(historical_program_terms),
    nrow(in_scope_program_terms),
    nrow(programs),
    nrow(program_term_map),
    nrow(program_texts)
  )
)

# Concrete regression/demo case: Concertzender Live
demo_compat_program <- compat_programs |>
  filter(program_id == 17016)

demo_aliases <- compat_program_terms |>
  filter(program_id == 17016) |>
  arrange(locale, term_id)

demo_program <- programs |>
  filter(source_id == "17016")

demo_texts <- program_texts |>
  filter(source_id == "17016") |>
  arrange(locale)

demo_term_map <- program_term_map |>
  filter(source_program_id == "17016") |>
  arrange(term_id)

demo_compat_program
demo_aliases
demo_program
demo_texts
demo_term_map
