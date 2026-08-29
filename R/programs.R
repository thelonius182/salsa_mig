prepare_wp_program_compat <- function(historical_program_terms,
                                      in_scope_program_terms) {
  required_columns <- c("term_id",
                        "source_title",
                        "source_slug",
                        "parent_term_id",
                        "language_slug")
  
  missing_columns <- setdiff(required_columns, names(historical_program_terms))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required WordPress program columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  if (!"term_id" %in% names(in_scope_program_terms)) {
    stop("In-scope WordPress program terms are missing term_id")
  }
  
  terms <- historical_program_terms |>
    transmute(
      term_id = as.character(term_id),
      term_id_num = suppressWarnings(as.numeric(term_id)),
      source_title = as.character(source_title),
      source_slug = as.character(source_slug),
      parent_term_id = as.numeric(parent_term_id),
      locale = case_match(
        as.character(language_slug),
        "pll_nl" ~ "nl",
        "pll_en" ~ "en",
        .default = NA_character_
      ),
      slug_stem = str_remove(source_slug, "__.*$")
    )
  
  if (any(is.na(terms$term_id_num))) {
    stop("WordPress program term_id must be numeric")
  }
  
  if (any(is.na(terms$parent_term_id) |
          terms$parent_term_id == 0)) {
    stop("Historical program input contains structural programma_genre terms")
  }
  
  if (any(is.na(terms$locale))) {
    stop("Unexpected WordPress program language")
  }
  
  if (any(is.na(terms$source_title) |
          str_trim(terms$source_title) == "")) {
    stop("WordPress program term is missing source_title")
  }
  
  if (any(is.na(terms$source_slug) |
          str_trim(terms$source_slug) == "")) {
    stop("WordPress program term is missing source_slug")
  }
  
  duplicate_terms <- terms |>
    count(term_id) |>
    filter(n > 1L)
  
  if (nrow(duplicate_terms) > 0) {
    stop(
      "Duplicate WordPress program term_id: ",
      paste(duplicate_terms$term_id, collapse = ", ")
    )
  }
  
  #
  # Legacy programma_genre aliases identify the same logical program when:
  #
  # 1. their slug stem is the same, OR
  # 2. their localized WordPress title is exactly the same.
  #
  # Connected components make this relationship transitive.
  #
  term_nodes <- terms |>
    mutate(
      term_node = str_c("term:", term_id),
      stem_node = str_c("stem:", slug_stem),
      title_node = str_c("title:", locale, ":", source_title)
    )
  
  alias_edges <- bind_rows(
    term_nodes |>
      transmute(from = term_node, to = stem_node),
    term_nodes |>
      transmute(from = term_node, to = title_node)
  )
  
  alias_graph <- graph_from_data_frame(alias_edges, directed = FALSE)
  
  memberships <- components(alias_graph)$membership
  
  term_components <- tibble(term_node = names(memberships),
                            component = unname(memberships)) |>
    filter(str_starts(term_node, "term:"))
  
  terms <- term_nodes |>
    left_join(term_components, by = "term_node")
  
  if (any(is.na(terms$component))) {
    stop("WordPress program term could not be assigned to a component")
  }
  
  #
  # A logical program may have only one title in each locale.
  #
  title_conflicts <- terms |>
    group_by(component, locale) |>
    summarise(title_count = n_distinct(source_title), .groups = "drop") |>
    filter(title_count > 1L)
  
  if (nrow(title_conflicts) > 0) {
    stop("Program alias grouping produced conflicting localized titles")
  }
  
  #
  # Scope is determined by broadcast usage from 2018-01-01 onward,
  # but identity is derived from the complete historical alias set.
  #
  in_scope_term_ids <- in_scope_program_terms |>
    pull(term_id) |>
    as.character() |>
    unique()
  
  unknown_scope_terms <- setdiff(in_scope_term_ids, terms$term_id)
  
  if (length(unknown_scope_terms) > 0) {
    stop(
      "In-scope program terms missing from historical term set: ",
      paste(unknown_scope_terms, collapse = ", ")
    )
  }
  
  in_scope_components <- terms |>
    filter(term_id %in% in_scope_term_ids) |>
    distinct(component)
  
  scoped_terms <- terms |>
    semi_join(in_scope_components, by = "component")
  
  #
  # Stable compatibility identity:
  # lowest historical NL term_id, otherwise lowest historical EN term_id.
  #
  identities <- scoped_terms |>
    group_by(component) |>
    summarise(
      nl_min_term_id = if (any(locale == "nl")) {
        min(term_id_num[locale == "nl"])
      } else {
        NA_real_
      },
      en_min_term_id = if (any(locale == "en")) {
        min(term_id_num[locale == "en"])
      } else {
        NA_real_
      },
      .groups = "drop"
    ) |>
    mutate(program_id = coalesce(nl_min_term_id, en_min_term_id))
  
  titles <- scoped_terms |>
    group_by(component) |>
    summarise(
      title_nl = if (any(locale == "nl")) {
        first(source_title[locale == "nl"])
      } else {
        NA_character_
      },
      title_en = if (any(locale == "en")) {
        first(source_title[locale == "en"])
      } else {
        NA_character_
      },
      .groups = "drop"
    )
  
  #
  # Salsa program slug = slug stem of the canonical historical term.
  #
  canonical_slugs <- identities |>
    left_join(
      scoped_terms |>
        select(component, term_id_num, canonical_source_slug = source_slug),
      by = c("component", "program_id" = "term_id_num")
    ) |>
    mutate(canonical_slug = str_remove(canonical_source_slug, "__.*$"))
  
  if (any(
    is.na(canonical_slugs$canonical_slug) |
    str_trim(canonical_slugs$canonical_slug) == ""
  )) {
    stop("Program is missing canonical slug")
  }
  
  duplicate_slugs <- canonical_slugs |>
    count(canonical_slug) |>
    filter(n > 1L)
  
  if (nrow(duplicate_slugs) > 0) {
    stop(
      "Duplicate canonical program slug: ",
      paste(duplicate_slugs$canonical_slug, collapse = ", ")
    )
  }
  
  compat_programs <- identities |>
    left_join(titles, by = "component") |>
    transmute(program_id, title_nl, title_en) |>
    arrange(program_id)
  
  compat_program_terms <- scoped_terms |>
    left_join(identities |>
                select(component, program_id), by = "component") |>
    left_join(canonical_slugs |>
                select(component, canonical_slug), by = "component") |>
    transmute(
      term_id = term_id_num,
      program_id,
      locale,
      source_title,
      
      # Compatibility field consumed by build_programs().
      # This is deliberately the logical Salsa slug,
      # not the raw genre-specific WordPress alias slug.
      source_slug = canonical_slug
    ) |>
    arrange(program_id, locale, term_id)
  
  list(compat_programs = compat_programs,
       compat_program_terms = compat_program_terms)
}

build_programs <- function(compat_programs, compat_program_terms) {
  canonical_slugs <- compat_program_terms |>
    transmute(
      source_id = as.character(program_id),
      term_id = as.character(term_id),
      slug = source_slug |>
        as.character() |>
        str_trim() |>
        na_if("")
    ) |>
    filter(source_id == term_id) |>
    select(source_id, slug)
  
  programs <- compat_programs |>
    transmute(source_id = as.character(program_id),
              id = program_uuid(program_id)) |>
    left_join(canonical_slugs, by = "source_id")
  
  if (any(is.na(programs$slug))) {
    stop(
      "Missing canonical slug for program_id: ",
      paste(programs$source_id[is.na(programs$slug)], collapse = ", ")
    )
  }
  
  duplicate_slugs <- programs |>
    count(slug) |>
    filter(n > 1)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Duplicate canonical program slug: ",
         paste(duplicate_slugs$slug, collapse = ", "))
  }
  
  programs
}

build_program_texts <- function(compat_programs) {
  program_texts <- compat_programs |>
    transmute(
      source_id = as.character(program_id),
      program_id = program_uuid(program_id),
      nl = clean_lookup_name(title_nl),
      en = clean_lookup_name(title_en)
    ) |>
    pivot_longer(cols = c(nl, en),
                 names_to = "locale",
                 values_to = "title") |>
    filter(!is.na(title)) |>
    mutate(description = NA_character_) |>
    select(source_id, program_id, locale, title, description)
  
  missing_titles <- compat_programs |>
    transmute(
      source_id = as.character(program_id),
      has_title = !is.na(clean_lookup_name(title_nl)) |
        !is.na(clean_lookup_name(title_en))
    ) |>
    filter(!has_title)
  
  if (nrow(missing_titles) > 0) {
    stop("Programs without any title: ",
         paste(missing_titles$source_id, collapse = ", "))
  }
  
  program_texts
}

build_program_term_map <- function(compat_program_terms) {
  program_term_map <- compat_program_terms |>
    transmute(
      term_id = as.character(term_id),
      source_program_id = as.character(program_id),
      program_id = program_uuid(program_id)
    ) |>
    distinct()
  
  conflicts <- program_term_map |>
    count(term_id, name = "n_programs") |>
    filter(n_programs > 1)
  
  if (nrow(conflicts) > 0) {
    stop(
      "WordPress program terms mapped to multiple programs: ",
      paste(conflicts$term_id, collapse = ", ")
    )
  }
  
  program_term_map
}

