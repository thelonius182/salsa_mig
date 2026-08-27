pacman::p_load(DBI, RMariaDB, dplyr, tidyr, purrr, stringr, jsonlite, openssl)

# Permanent namespace for deterministic UUIDv5 IDs.
# DO NOT CHANGE: changing this value changes every generated Salsa UUID.
SALSA_UUID_NAMESPACE <- "32683dc4-8bef-46ad-9438-9badcb46fdad"

uuid_v5 <- function(name, namespace = SALSA_UUID_NAMESPACE) {
  namespace_raw <- namespace |>
    str_remove_all("-") |>
    str_extract_all("..") |>
    unlist() |>
    strtoi(base = 16L) |>
    as.raw()
  
  make_uuid <- function(name) {
    hash <- c(
      namespace_raw,
      charToRaw(enc2utf8(name))
    ) |>
      sha1()
    
    uuid_raw <- hash[1:16]
    
    # RFC 4122 / RFC 9562:
    # version = 5
    uuid_raw[7] <- as.raw(
      bitwOr(bitwAnd(as.integer(uuid_raw[7]), 0x0f), 0x50)
    )
    
    # variant = RFC 4122
    uuid_raw[9] <- as.raw(
      bitwOr(bitwAnd(as.integer(uuid_raw[9]), 0x3f), 0x80)
    )
    
    hex <- paste0(
      sprintf("%02x", as.integer(uuid_raw)),
      collapse = ""
    )
    
    paste(
      substr(hex, 1, 8),
      substr(hex, 9, 12),
      substr(hex, 13, 16),
      substr(hex, 17, 20),
      substr(hex, 21, 32),
      sep = "-"
    )
  }
  
  vapply(name, make_uuid, character(1), USE.NAMES = FALSE)
}

# salsa_uuid <- function(type, source_id) {
#   # Deterministic UUID source-key convention
#   #
#   # WordPress objects:
#   #   wp_post:<ID>
#   #   wp_term:<term_id>
#   #   wp_user:<ID>
#   #
#   # Salsa-only entities derived from WordPress data will get their own explicit type prefix later. Never reuse a prefix for a
#   # different kind of source object.
#   uuid_v5(
#     paste(type, source_id, sep = ":")
#   )
# }

UUID_TYPES <- c(
  wp_post = "wp_post",
  wp_term = "wp_term",
  wp_user = "wp_user",
  program = "program",
  episode = "episode",
  broadcast = "broadcast"
)

# salsa_uuid <- function(type, source_id) {
#   if (!type %in% UUID_TYPES) {
#     stop(
#       "Unknown UUID type: ", type,
#       ". Add it explicitly to UUID_TYPES first."
#     )
#   }
#   
#   uuid_v5(
#     paste(type, source_id, sep = ":")
#   )
# }

salsa_uuid <- function(type, source_id) {
  if (
    length(type) != 1L ||
    is.na(type) ||
    !type %in% UUID_TYPES
  ) {
    stop(
      "Unknown UUID type: ", type,
      ". Add it explicitly to UUID_TYPES first."
    )
  }
  
  source_id <- as.character(source_id)
  
  if (any(source_id == "", na.rm = TRUE)) {
    stop("source_id must not be an empty string.")
  }
  
  result <- rep(NA_character_, length(source_id))
  present <- !is.na(source_id)
  
  result[present] <- uuid_v5(
    paste(type, source_id[present], sep = ":")
  )
  
  result
}

post_uuid <- function(id) {
  salsa_uuid(UUID_TYPES[["wp_post"]], id)
}

term_uuid <- function(id) {
  salsa_uuid(UUID_TYPES[["wp_term"]], id)
}

user_uuid <- function(id) {
  salsa_uuid(UUID_TYPES[["wp_user"]], id)
}

clean_lookup_name <- function(x) {
  x |>
    as.character() |>
    str_replace_all("\u00a0", " ") |>
    str_squish() |>
    na_if("")
}

build_lookup <- function(x) {
  tibble(
    name = clean_lookup_name(x)
  ) |>
    filter(!is.na(name)) |>
    distinct(name)
}

build_term_lookup <- function(data, id_col, name_col) {
  data |>
    transmute(
      source_id = as.character({{ id_col }}),
      id = term_uuid({{ id_col }}),
      name = clean_lookup_name({{ name_col }})
    ) |>
    filter(
      !is.na(source_id),
      !is.na(name)
    ) |>
    distinct(source_id, .keep_all = TRUE)
}

program_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["program"]], source_id)
}

episode_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["episode"]], source_id)
}

broadcast_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["broadcast"]], source_id)
}

clean_optional_text <- function(x) {
  x <- as.character(x)
  x <- str_trim(x)
  x[x == ""] <- NA_character_
  x
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

build_broadcasts <- function(radio_rows) {
  broadcasts <- radio_rows |>
    transmute(
      source_id = as.character(broadcast_source_key),
      episode_source_id = as.character(episode_source_key),
      id = broadcast_uuid(broadcast_source_key),
      episode_id = episode_uuid(episode_source_key),
      starts_at,
      ends_at
    )
  
  missing_keys <- broadcasts |>
    filter(is.na(source_id) |
             is.na(episode_source_id) |
             is.na(starts_at) |
             is.na(ends_at))
  
  if (nrow(missing_keys) > 0) {
    stop("Broadcast rows contain missing identity or timing fields.")
  }
  
  conflicts <- broadcasts |>
    group_by(source_id) |>
    summarise(
      n_episodes = n_distinct(episode_source_id),
      n_starts = n_distinct(starts_at),
      n_ends = n_distinct(ends_at),
      .groups = "drop"
    ) |>
    filter(n_episodes > 1 |
             n_starts > 1 |
             n_ends > 1)
  
  if (nrow(conflicts) > 0) {
    stop(
      "Conflicting localized rows for broadcast_source_key: ",
      paste(conflicts$source_id, collapse = ", ")
    )
  }
  
  broadcasts <- broadcasts |>
    distinct(source_id, .keep_all = TRUE)
  
  invalid_times <- broadcasts |>
    filter(ends_at <= starts_at)
  
  if (nrow(invalid_times) > 0) {
    stop(
      "Broadcast end time is not after start time for: ",
      paste(invalid_times$source_id, collapse = ", ")
    )
  }
  
  broadcasts
}

build_episodes <- function(episode_rows, program_term_map) {
  resolved <- episode_rows |>
    transmute(
      source_id = as.character(episode_source_key),
      program_term_id = as.character(program_term_id),
      locale = as.character(locale),
      slug = post_name |>
        as.character() |>
        str_trim() |>
        na_if("")
    ) |>
    filter(!is.na(source_id)) |>
    left_join(
      program_term_map |>
        select(term_id, program_id),
      by = c("program_term_id" = "term_id")
    )
  
  missing_programs <- resolved |>
    filter(is.na(program_id))
  
  if (nrow(missing_programs) > 0) {
    stop("Unmapped program term_id: ", paste(unique(missing_programs$program_term_id), collapse = ", "))
  }
  
  program_conflicts <- resolved |>
    group_by(source_id) |>
    summarise(n_programs = n_distinct(program_id), .groups = "drop") |>
    filter(n_programs != 1L)
  
  if (nrow(program_conflicts) > 0) {
    stop(
      "Episode mapped to multiple programs: ",
      paste(program_conflicts$source_id, collapse = ", ")
    )
  }
  
  slug_conflicts <- resolved |>
    filter(!is.na(slug)) |>
    group_by(source_id, locale) |>
    summarise(n_slugs = n_distinct(slug), .groups = "drop") |>
    filter(n_slugs > 1L)
  
  if (nrow(slug_conflicts) > 0) {
    stop("Conflicting episode slugs for: ",
         paste(
           paste0(slug_conflicts$source_id, "/", slug_conflicts$locale),
           collapse = ", "
         ))
  }
  
  episodes <- resolved |>
    filter(!is.na(slug)) |>
    mutate(locale_rank = case_when(locale == "nl" ~ 1L, locale == "en" ~ 2L, TRUE ~ 3L)) |>
    arrange(source_id, locale_rank, locale, slug) |>
    distinct(source_id, .keep_all = TRUE) |>
    transmute(
      source_id,
      id = episode_uuid(source_id),
      program_id,
      slug,
      image_id = NA_character_,
      audio_id = NA_character_,
      mood_wave = NA_integer_,
      mood_color = NA_integer_,
      mood_tempo = NA_integer_,
      mood_intensity = NA_integer_
    )
  
  missing_slugs <- resolved |>
    distinct(source_id) |>
    anti_join(episodes |>
                select(source_id), by = "source_id")
  
  if (nrow(missing_slugs) > 0) {
    stop("Episodes without a usable slug: ",
         paste(missing_slugs$source_id, collapse = ", "))
  }
  
  duplicate_slugs <- episodes |>
    count(program_id, slug, name = "n") |>
    filter(n > 1L)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Duplicate episode slug within a program.")
  }
  
  episodes
}

build_episode_texts <- function(episode_rows) {
  episode_texts <- episode_rows |>
    transmute(
      source_id = as.character(episode_source_key),
      episode_id = episode_uuid(episode_source_key),
      locale = as.character(locale),
      subtitle = NA_character_,
      description = clean_optional_text(description),
      content_raw = clean_optional_text(content)
    ) |>
    filter(!is.na(source_id), !is.na(locale))
  
  invalid_locales <- episode_texts |>
    filter(!locale %in% c("nl", "en"))
  
  if (nrow(invalid_locales) > 0) {
    stop("Unexpected episode locale: ", paste(unique(invalid_locales$locale), collapse = ", "))
  }
  
  conflicts <- episode_texts |>
    distinct(source_id, locale, subtitle, description, content_raw) |>
    count(source_id, locale, name = "n_versions") |>
    filter(n_versions > 1L)
  
  if (nrow(conflicts) > 0) {
    stop("Conflicting localized episode text for: ",
         paste(
           paste0(conflicts$source_id, "/", conflicts$locale),
           collapse = ", "
         ))
  }
  
  episode_texts |>
    distinct(source_id, locale, .keep_all = TRUE) |>
    mutate(content = NA_character_) |>
    select(source_id,
           episode_id,
           locale,
           subtitle,
           description,
           content,
           content_raw)
}

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

# START TESTS ----
c(
  post = salsa_uuid(UUID_TYPES[["wp_post"]], 74839),
  term = salsa_uuid(UUID_TYPES[["wp_term"]], 74839),
  user = salsa_uuid(UUID_TYPES[["wp_user"]], 74839)
)

identical(
  post_uuid(74839),
  salsa_uuid("wp_post", 74839)
)

c(
  valid = post_uuid(74839),
  missing = post_uuid(NA_integer_)
)

is.na(post_uuid(NA_integer_))

clean_lookup_name(
  c(
    "  Nuove   Musiche ",
    "Nieuw Ensemble",
    "",
    NA_character_
  )
)

test_terms <- tibble(
  term_id = c(101, 102, 102, 103),
  term_name = c(
    "Nieuw Ensemble",
    "  Nuove   Musiche ",
    "Nuove Musiche",
    ""
  )
)

build_term_lookup(
  test_terms,
  term_id,
  term_name
)

identical(
  translation_group_uuid(223729),
  translation_group_uuid(223729)
)

test_program_titles <- tibble(
  post_id = c(871100, 871101, 900119, 900120),
  translation_group_id = c(223729, 223729, 232571, 232571),
  language = c("nl", "en", "nl", "en"),
  post_title = c(
    "Nuove Musiche",
    "Nuove Musiche",
    "Programma Twee",
    "Programme Two"
  )
)

# build_translated_lookup(
#   test_program_titles,
#   translation_group_id,
#   language,
#   post_title
# )

# test_conflict <- tibble(
#   translation_group_id = c(223729, 223729),
#   language = c("nl", "nl"),
#   post_title = c(
#     "Nuove Musiche",
#     "Andere titel"
#   )
# )

# build_translated_lookup(
#   test_conflict,
#   translation_group_id,
#   language,
#   post_title
# )

c(
  program = program_uuid(27889),
  episode = episode_uuid(223729),
  broadcast = broadcast_uuid(223729)
)

test_compat_programs <- tibble(
  program_id = c(17016, 27889),
  title_nl = c(
    "Concertzender Live",
    "Nuove Musiche"
  ),
  title_en = c(
    "Concertzender Live",
    "Nuove Musiche"
  ),
  aliases_en = NA_character_
)

test_compat_program_terms <- tibble(
  term_id = c(17016, 17018, 27889),
  program_id = c(17016, 17016, 27889),
  locale = c("nl", "en", "nl"),
  source_title = c(
    "Concertzender Live",
    "Concertzender Live",
    "Nuove Musiche"
  ),
  source_slug = c(
    "concertzender-live__jazz-nl",
    "concertzender-live__jazz-en",
    "nuove-musiche"
  )
)

build_programs(
  test_compat_programs,
  test_compat_program_terms
)

test_compat_programs <- tibble(
  program_id = c(17016, 27889, 3052),
  title_nl = c(
    "Concertzender Live",
    "Nuove Musiche",
    "De gehoorde stilte"
  ),
  title_en = c(
    "Concertzender Live",
    "Nuove Musiche",
    NA
  ),
  aliases_en = c(
    NA,
    NA,
    NA
  )
)

build_program_texts(test_compat_programs)

build_program_term_map(test_compat_program_terms)

test_program_term_map <- build_program_term_map(
  test_compat_program_terms
)

identical(
  test_program_term_map$program_id[
    test_program_term_map$term_id == "17016"
  ],
  test_program_term_map$program_id[
    test_program_term_map$term_id == "17018"
  ]
)

# test the original + replay case we already verified in WordPress: ----
test_radio_rows <- tibble(
  broadcast_source_key = c(
    223729, 223729,
    232571, 232571
  ),
  episode_source_key = c(
    223729, 223729,
    223729, 223729
  ),
  locale = c(
    "nl", "en",
    "nl", "en"
  ),
  starts_at = as.POSIXct(
    c(
      "2026-02-19 19:00:00",
      "2026-02-19 19:00:00",
      "2026-04-02 19:00:00",
      "2026-04-02 19:00:00"
    ),
    tz = "UTC"
  ),
  ends_at = as.POSIXct(
    c(
      "2026-02-19 21:00:00",
      "2026-02-19 21:00:00",
      "2026-04-02 21:00:00",
      "2026-04-02 21:00:00"
    ),
    tz = "UTC"
  )
)

test_broadcasts <- build_broadcasts(test_radio_rows)

test_broadcasts

# test the identity/base row of episodes ----
test_episode_rows <- tibble(
  episode_source_key = c(
    223729,
    223729
  ),
  program_term_id = c(
    17016,
    17018
  ),
  locale = c(
    "nl",
    "en"
  ),
  post_name = c(
    "concertzender-live-2026-02-19",
    "concertzender-live-2026-02-19-en"
  )
)

test_episodes <- build_episodes(
  test_episode_rows,
  test_program_term_map
)

test_episodes

# test_episode_text_rows ----
test_episode_text_rows <- tibble(
  episode_source_key = c(
    223729,
    223729
  ),
  locale = c(
    "nl",
    "en"
  ),
  description = c(
    "Een uitzending met hedendaagse muziek.",
    "A broadcast featuring contemporary music."
  ),
  content = c(
    "<p>Nederlandse uitgebreide inhoud.</p>",
    "<p>English extended content.</p>"
  )
)

test_episode_texts <- build_episode_texts(
  test_episode_text_rows
)

test_episode_texts

# test_compat_genres ----
test_compat_genres <- tibble(
  genre_key = c(
    "wereld",
    "klassiek",
    "jazz"
  ),
  title_nl = c(
    "Wereld",
    "Klassiek",
    "Jazz"
  ),
  title_en = c(
    "World Music",
    "Classical Music",
    "Jazz"
  )
)

test_genres <- build_genres(test_compat_genres)

test_genres

# test_genre_texts ----
test_genre_texts <- build_genre_texts(
  test_compat_genres,
  test_genres
)

test_genre_texts

# test_compat_program_genres ----
test_compat_program_genres <- tibble(
  program_id = c(
    17016,
    17016,
    17016
  ),
  genre_key = c(
    "wereld",
    "jazz",
    "klassiek"
  )
)

test_program_genres <- build_program_genres(
  test_compat_program_genres,
  test_genres
)

test_program_genres

# test_subgenre_rows ----
test_subgenre_rows <- tibble(
  subgenre_term_id = c(
    50101,
    50102,
    50103
  ),
  genre_key = c(
    "jazz",
    "jazz",
    "klassiek"
  ),
  subgenre_slug = c(
    "bebop",
    "free-jazz",
    "barok"
  ),
  subgenre_name = c(
    "Bebop",
    "Free Jazz",
    "Barok"
  )
)

test_subgenres <- build_subgenres(
  test_subgenre_rows,
  test_genres
)

test_subgenres

# test_episode_subgenre_rows ----
test_episode_subgenre_rows <- tibble(
  episode_source_key = c(
    223729,
    223729,
    223729,
    223729
  ),
  subgenre_term_id = c(
    50103,
    50101,
    50102,
    50101
  )
)

test_episode_subgenres <- build_episode_subgenres(
  test_episode_subgenre_rows,
  test_episodes,
  test_subgenres,
  test_program_genres
)

test_episode_subgenres
