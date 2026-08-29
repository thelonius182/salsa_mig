build_genres <- function(compat_genres) {
  genres <- compat_genres |>
    transmute(genre_key = clean_lookup_name(genre_key),
              slug = clean_lookup_name(genre_key))
  
  if (any(is.na(genres$genre_key))) {
    stop("Genres contain a missing genre_key.")
  }
  
  duplicate_keys <- genres |>
    count(genre_key) |>
    filter(n > 1L)
  
  if (nrow(duplicate_keys) > 0) {
    stop("Duplicate genre_key: ",
         paste(duplicate_keys$genre_key, collapse = ", "))
  }
  
  genres |>
    arrange(genre_key) |>
    mutate(id = row_number()) |>
    select(genre_key, id, slug)
}

build_genre_texts <- function(compat_genres, genres) {
  genre_texts <- compat_genres |>
    transmute(
      genre_key = clean_lookup_name(genre_key),
      nl = clean_lookup_name(title_nl),
      en = clean_lookup_name(title_en)
    ) |>
    left_join(genres |>
                select(genre_key, genre_id = id), by = "genre_key")
  
  missing_genres <- genre_texts |>
    filter(is.na(genre_id))
  
  if (nrow(missing_genres) > 0) {
    stop(
      "Genre text refers to unknown genre_key: ",
      paste(missing_genres$genre_key, collapse = ", ")
    )
  }
  
  genre_texts |>
    pivot_longer(cols = c(nl, en),
                 names_to = "locale",
                 values_to = "name") |>
    filter(!is.na(name)) |>
    select(genre_id, locale, name) |>
    arrange(genre_id, match(locale, c("nl", "en")))
}

build_program_genres <- function(compat_program_genres, genres) {
  program_genres <- compat_program_genres |>
    transmute(
      source_program_id = as.character(program_id),
      program_id = program_uuid(program_id),
      genre_key = clean_lookup_name(genre_key)
    ) |>
    left_join(genres |>
                select(genre_key, genre_id = id), by = "genre_key")
  
  missing_genres <- program_genres |>
    filter(is.na(genre_id))
  
  if (nrow(missing_genres) > 0) {
    stop("Program genre refers to unknown genre_key: ",
         paste(unique(missing_genres$genre_key), collapse = ", "))
  }
  
  duplicates <- program_genres |>
    count(source_program_id, genre_id) |>
    filter(n > 1L)
  
  if (nrow(duplicates) > 0) {
    stop("Duplicate program/genre relations found.")
  }
  
  program_genres |>
    arrange(source_program_id, genre_id) |>
    group_by(source_program_id) |>
    mutate(position = row_number()) |>
    ungroup() |>
    select(source_program_id, program_id, genre_key, genre_id, position)
}

build_subgenres <- function(subgenre_rows, genres) {
  subgenres <- subgenre_rows |>
    transmute(
      source_id = as.character(subgenre_term_id),
      id = as.integer(subgenre_term_id),
      genre_key = clean_lookup_name(genre_key),
      slug = clean_lookup_name(subgenre_slug),
      name = clean_lookup_name(subgenre_name)
    ) |>
    left_join(genres |>
                select(genre_key, genre_id = id), by = "genre_key")
  
  missing_values <- subgenres |>
    filter(is.na(source_id) |
             is.na(genre_id) |
             is.na(slug) |
             is.na(name))
  
  if (nrow(missing_values) > 0) {
    stop("Subgenres contain missing identity, genre, slug or name.")
  }
  
  conflicting_ids <- subgenres |>
    distinct(source_id, genre_id, slug, name) |>
    count(source_id, name = "n_versions") |>
    filter(n_versions > 1L)
  
  if (nrow(conflicting_ids) > 0) {
    stop(
      "Conflicting data for subgenre term_id: ",
      paste(conflicting_ids$source_id, collapse = ", ")
    )
  }
  
  duplicate_slugs <- subgenres |>
    distinct(source_id, genre_id, slug) |>
    count(genre_id, slug) |>
    filter(n > 1L)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Duplicate subgenre slug within a genre.")
  }
  
  subgenres |>
    distinct(source_id, .keep_all = TRUE) |>
    arrange(id) |>
    select(source_id, id, genre_key, genre_id, slug, name)
}

build_episode_subgenres <- function(episode_subgenre_rows,
                                    episodes,
                                    subgenres,
                                    program_genres) {
  relations <- episode_subgenre_rows |>
    transmute(
      source_episode_id = as.character(episode_source_key),
      subgenre_id = as.integer(subgenre_term_id)
    )
  
  missing_ids <- relations |>
    filter(is.na(source_episode_id) |
             is.na(subgenre_id))
  
  if (nrow(missing_ids) > 0) {
    stop("Episode/subgenre relations contain missing IDs.")
  }
  
  # Localized WordPress posts can produce the same relation more than once.
  relations <- relations |>
    distinct()
  
  relations <- relations |>
    left_join(episodes |>
                select(
                  source_episode_id = source_id,
                  episode_id = id,
                  program_id
                ),
              by = "source_episode_id")
  
  unknown_episodes <- relations |>
    filter(is.na(episode_id))
  
  if (nrow(unknown_episodes) > 0) {
    stop("Subgenre relation refers to unknown episode: ",
         paste(unique(unknown_episodes$source_episode_id), collapse = ", "))
  }
  
  relations <- relations |>
    left_join(subgenres |>
                select(subgenre_id = id, genre_id), by = "subgenre_id")
  
  unknown_subgenres <- relations |>
    filter(is.na(genre_id))
  
  if (nrow(unknown_subgenres) > 0) {
    stop("Episode refers to unknown subgenre_id: ",
         paste(unique(unknown_subgenres$subgenre_id), collapse = ", "))
  }
  
  allowed_genres <- program_genres |>
    distinct(program_id, genre_id) |>
    mutate(allowed = TRUE)
  
  relations <- relations |>
    left_join(allowed_genres, by = c("program_id", "genre_id"))
  
  invalid_relations <- relations |>
    filter(is.na(allowed))
  
  if (nrow(invalid_relations) > 0) {
    stop("Episode uses a subgenre outside its program genres.")
  }
  
  relations |>
    arrange(source_episode_id, subgenre_id) |>
    group_by(source_episode_id) |>
    mutate(position = row_number()) |>
    ungroup() |>
    select(source_episode_id, episode_id, subgenre_id, position)
}

