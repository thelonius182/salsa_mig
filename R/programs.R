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

