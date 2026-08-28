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

UUID_TYPES <- c(
  wp_post = "wp_post",
  wp_term = "wp_term",
  wp_user = "wp_user",
  program = "program",
  episode = "episode",
  broadcast = "broadcast",
  artist = "artist",
  editor = "editor",
  image = "image",
  audio = "audio",
  post_article = "post_article",
  venue = "venue",
  recording_collection = "recording_collection",
  recorded_concert = "recorded_concert"
)

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

artist_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["artist"]], source_id)
}

editor_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["editor"]], source_id)
}

image_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["image"]], source_id)
}

audio_uuid <- function(source_id) {
  salsa_uuid(UUID_TYPES[["audio"]], source_id)
}

post_article_uuid <- function(post_source_key) {
  salsa_uuid("post_article", post_source_key)
}

venue_uuid <- function(venue_source_key) {
  salsa_uuid("venue", venue_source_key)
}

recording_collection_uuid <- function(recording_collection_source_key) {
  salsa_uuid("recording_collection", recording_collection_source_key)
}

recorded_concert_uuid <- function(recorded_concert_source_key) {
  salsa_uuid("recorded_concert", recorded_concert_source_key)
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

build_episodes <- function(episode_rows,
                           program_term_map,
                           images,
                           audio_files) {
  resolved <- episode_rows |>
    transmute(
      source_id = as.character(episode_source_key),
      program_term_id = as.character(program_term_id),
      locale = as.character(locale),
      slug = post_name |>
        as.character() |>
        str_trim() |>
        na_if(""),
      image_source_id = as.character(image_source_id),
      audio_source_id = as.character(audio_source_id),
      mood_wave = as.integer(mood_wave),
      mood_color = as.integer(mood_color),
      mood_tempo = as.integer(mood_tempo),
      mood_intensity = as.integer(mood_intensity)
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
  
  asset_conflicts <- resolved |>
    group_by(source_id) |>
    summarise(
      n_images = n_distinct(image_source_id, na.rm = TRUE),
      n_audio = n_distinct(audio_source_id, na.rm = TRUE),
      .groups = "drop"
    ) |>
    filter(n_images > 1L |
             n_audio > 1L)
  
  if (nrow(asset_conflicts) > 0) {
    stop(
      "Episode has conflicting image or audio sources: ",
      paste(asset_conflicts$source_id, collapse = ", ")
    )
  }
  
  image_refs <- resolved |>
    filter(!is.na(image_source_id)) |>
    distinct(source_id, image_source_id) |>
    left_join(images |>
                select(image_source_id = source_id, image_id = id),
              by = "image_source_id")
  
  unknown_images <- image_refs |>
    filter(is.na(image_id))
  
  if (nrow(unknown_images) > 0) {
    stop("Episode refers to unknown image source ID: ",
         paste(unique(unknown_images$image_source_id), collapse = ", "))
  }
  
  audio_refs <- resolved |>
    filter(!is.na(audio_source_id)) |>
    distinct(source_id, audio_source_id) |>
    left_join(audio_files |>
                select(audio_source_id = source_id, audio_id = id),
              by = "audio_source_id")
  
  unknown_audio <- audio_refs |>
    filter(is.na(audio_id))
  
  if (nrow(unknown_audio) > 0) {
    stop("Episode refers to unknown audio source ID: ",
         paste(unique(unknown_audio$audio_source_id), collapse = ", "))
  }
  
  invalid_moods <- resolved |>
    filter(if_any(
      c(mood_wave, mood_color, mood_tempo, mood_intensity),
      ~ !is.na(.x) & (.x < 0L | .x > 255L)
    ))
  
  if (nrow(invalid_moods) > 0) {
    stop("Episode mood values must be between 0 and 255 when present.")
  }
  
  mood_conflicts <- resolved |>
    group_by(source_id) |>
    summarise(
      n_wave = n_distinct(mood_wave, na.rm = TRUE),
      n_color = n_distinct(mood_color, na.rm = TRUE),
      n_tempo = n_distinct(mood_tempo, na.rm = TRUE),
      n_intensity = n_distinct(mood_intensity, na.rm = TRUE),
      .groups = "drop"
    ) |>
    filter(n_wave > 1L |
             n_color > 1L |
             n_tempo > 1L |
             n_intensity > 1L)
  
  if (nrow(mood_conflicts) > 0) {
    stop(
      "Episode has conflicting mood values: ",
      paste(mood_conflicts$source_id, collapse = ", ")
    )
  }
  
  mood_refs <- resolved |>
    group_by(source_id) |>
    summarise(across(
      c(mood_wave, mood_color, mood_tempo, mood_intensity),
      ~ first(.x[!is.na(.x)], default = NA_integer_)
    ), .groups = "drop")
  
  episodes <- resolved |>
    filter(!is.na(slug)) |>
    mutate(locale_rank = case_when(locale == "nl" ~ 1L, locale == "en" ~ 2L, TRUE ~ 3L)) |>
    arrange(source_id, locale_rank, locale, slug) |>
    distinct(source_id, .keep_all = TRUE) |>
    select(source_id, program_id, slug) |>
    left_join(image_refs |>
                select(source_id, image_id), by = "source_id") |>
    left_join(audio_refs |>
                select(source_id, audio_id), by = "source_id") |>
    left_join(mood_refs, by = "source_id") |>
    transmute(
      source_id,
      id = episode_uuid(source_id),
      program_id,
      slug,
      image_id,
      audio_id,
      mood_wave,
      mood_color,
      mood_tempo,
      mood_intensity
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
    mutate(content = build_content_json(content_raw)) |>
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

build_artists <- function(artist_rows) {
  artists <- artist_rows |>
    transmute(
      source_id = as.character(artist_source_id),
      id = artist_uuid(artist_source_id),
      name = clean_lookup_name(artist_name)
    )
  
  missing_values <- artists |>
    filter(is.na(source_id) |
             is.na(name))
  
  if (nrow(missing_values) > 0) {
    stop("Artists contain missing source IDs or names.")
  }
  
  conflicts <- artists |>
    distinct(source_id, name) |>
    count(source_id, name = "n_names") |>
    filter(n_names > 1L)
  
  if (nrow(conflicts) > 0) {
    stop(
      "Conflicting names for artist source ID: ",
      paste(conflicts$source_id, collapse = ", ")
    )
  }
  
  artists |>
    distinct(source_id, .keep_all = TRUE) |>
    arrange(source_id) |>
    select(source_id, id, name)
}

build_episode_artists <- function(episode_artist_rows, episodes, artists) {
  relations <- episode_artist_rows |>
    transmute(
      source_episode_id = as.character(episode_source_key),
      artist_source_id = as.character(artist_source_id),
      position = as.integer(position)
    )
  
  missing_values <- relations |>
    filter(is.na(source_episode_id) |
             is.na(artist_source_id) |
             is.na(position))
  
  if (nrow(missing_values) > 0) {
    stop("Episode/artist relations contain missing IDs or positions.")
  }
  
  invalid_positions <- relations |>
    filter(position < 1L)
  
  if (nrow(invalid_positions) > 0) {
    stop("Episode/artist positions must be at least 1.")
  }
  
  # Localized WordPress rows may repeat the same credit relation.
  relations <- relations |>
    distinct()
  
  position_conflicts <- relations |>
    count(source_episode_id, artist_source_id, name = "n_positions") |>
    filter(n_positions > 1L)
  
  if (nrow(position_conflicts) > 0) {
    stop("Artist has conflicting positions within an episode.")
  }
  
  duplicate_positions <- relations |>
    count(source_episode_id, position, name = "n_artists") |>
    filter(n_artists > 1L)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple artists have the same position within an episode.")
  }
  
  relations <- relations |>
    left_join(episodes |>
                select(source_episode_id = source_id, episode_id = id),
              by = "source_episode_id")
  
  unknown_episodes <- relations |>
    filter(is.na(episode_id))
  
  if (nrow(unknown_episodes) > 0) {
    stop("Artist relation refers to unknown episode: ",
         paste(unique(unknown_episodes$source_episode_id), collapse = ", "))
  }
  
  relations <- relations |>
    left_join(artists |>
                select(artist_source_id = source_id, artist_id = id),
              by = "artist_source_id")
  
  unknown_artists <- relations |>
    filter(is.na(artist_id))
  
  if (nrow(unknown_artists) > 0) {
    stop("Episode refers to unknown artist source ID: ",
         paste(unique(unknown_artists$artist_source_id), collapse = ", "))
  }
  
  relations |>
    arrange(source_episode_id, position) |>
    select(source_episode_id,
           episode_id,
           artist_source_id,
           artist_id,
           position)
}

build_editors <- function(editor_rows) {
  editors <- editor_rows |>
    transmute(
      source_id = as.character(editor_source_id),
      id = editor_uuid(editor_source_id),
      name = clean_lookup_name(editor_name)
    )
  
  missing_values <- editors |>
    filter(is.na(source_id) |
             is.na(name))
  
  if (nrow(missing_values) > 0) {
    stop("Editors contain missing source IDs or names.")
  }
  
  conflicts <- editors |>
    distinct(source_id, name) |>
    count(source_id, name = "n_names") |>
    filter(n_names > 1L)
  
  if (nrow(conflicts) > 0) {
    stop(
      "Conflicting names for editor source ID: ",
      paste(conflicts$source_id, collapse = ", ")
    )
  }
  
  editors |>
    distinct(source_id, .keep_all = TRUE) |>
    arrange(source_id) |>
    select(source_id, id, name)
}

build_episode_editors <- function(episode_editor_rows, episodes, editors) {
  relations <- episode_editor_rows |>
    transmute(
      source_episode_id = as.character(episode_source_key),
      editor_source_id = as.character(editor_source_id),
      role = as.character(role),
      position = as.integer(position)
    )
  
  missing_values <- relations |>
    filter(is.na(source_episode_id) |
             is.na(editor_source_id) |
             is.na(role) |
             is.na(position))
  
  if (nrow(missing_values) > 0) {
    stop("Episode/editor relations contain missing IDs, roles or positions.")
  }
  
  invalid_roles <- relations |>
    filter(!role %in% c("producer", "producer_presenter", "unspecified"))
  
  if (nrow(invalid_roles) > 0) {
    stop("Unexpected editor role: ", paste(unique(invalid_roles$role), collapse = ", "))
  }
  
  invalid_positions <- relations |>
    filter(position < 1L)
  
  if (nrow(invalid_positions) > 0) {
    stop("Episode/editor positions must be at least 1.")
  }
  
  # Localized WordPress rows may repeat the same credit relation.
  relations <- relations |>
    distinct()
  
  editor_conflicts <- relations |>
    group_by(source_episode_id, editor_source_id) |>
    summarise(
      n_roles = n_distinct(role),
      n_positions = n_distinct(position),
      .groups = "drop"
    ) |>
    filter(n_roles > 1L |
             n_positions > 1L)
  
  if (nrow(editor_conflicts) > 0) {
    stop("Editor has conflicting role or position within an episode.")
  }
  
  duplicate_positions <- relations |>
    count(source_episode_id, position, name = "n_editors") |>
    filter(n_editors > 1L)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple editors have the same position within an episode.")
  }
  
  relations <- relations |>
    left_join(episodes |>
                select(source_episode_id = source_id, episode_id = id),
              by = "source_episode_id")
  
  unknown_episodes <- relations |>
    filter(is.na(episode_id))
  
  if (nrow(unknown_episodes) > 0) {
    stop("Editor relation refers to unknown episode: ",
         paste(unique(unknown_episodes$source_episode_id), collapse = ", "))
  }
  
  relations <- relations |>
    left_join(editors |>
                select(editor_source_id = source_id, editor_id = id),
              by = "editor_source_id")
  
  unknown_editors <- relations |>
    filter(is.na(editor_id))
  
  if (nrow(unknown_editors) > 0) {
    stop("Episode refers to unknown editor source ID: ",
         paste(unique(unknown_editors$editor_source_id), collapse = ", "))
  }
  
  relations |>
    arrange(source_episode_id, position) |>
    select(source_episode_id,
           episode_id,
           editor_source_id,
           editor_id,
           role,
           position)
}

build_images <- function(image_rows) {
  images <- image_rows |>
    transmute(
      source_id = as.character(image_source_id),
      id = image_uuid(image_source_id),
      url = clean_optional_text(url),
      alt_text = clean_optional_text(alt_text),
      mime_type = clean_optional_text(mime_type),
      width_px = as.integer(width_px),
      height_px = as.integer(height_px)
    )
  
  missing_values <- images |>
    filter(is.na(source_id) |
             is.na(url))
  
  if (nrow(missing_values) > 0) {
    stop("Images contain missing source IDs or URLs.")
  }
  
  invalid_dimensions <- images |>
    filter((!is.na(width_px) & width_px < 1L) |
             (!is.na(height_px) & height_px < 1L))
  
  if (nrow(invalid_dimensions) > 0) {
    stop("Image dimensions must be positive when present.")
  }
  
  conflicts <- images |>
    distinct(source_id, url, alt_text, mime_type, width_px, height_px) |>
    count(source_id, name = "n_versions") |>
    filter(n_versions > 1L)
  
  if (nrow(conflicts) > 0) {
    stop("Conflicting data for image source ID: ",
         paste(conflicts$source_id, collapse = ", "))
  }
  
  images |>
    distinct(source_id, .keep_all = TRUE) |>
    arrange(source_id) |>
    select(source_id, id, url, alt_text, mime_type, width_px, height_px)
}

build_audio_files <- function(audio_rows) {
  audio_files <- audio_rows |>
    transmute(
      source_id = as.character(audio_source_id),
      id = audio_uuid(audio_source_id),
      url = clean_optional_text(url),
      file_name = clean_optional_text(file_name),
      mime_type = clean_optional_text(mime_type),
      duration_seconds = as.numeric(duration_seconds)
    )
  
  missing_values <- audio_files |>
    filter(is.na(source_id) |
             is.na(url))
  
  if (nrow(missing_values) > 0) {
    stop("Audio files contain missing source IDs or URLs.")
  }
  
  invalid_durations <- audio_files |>
    filter(!is.na(duration_seconds) &
             duration_seconds < 0)
  
  if (nrow(invalid_durations) > 0) {
    stop("Audio duration must not be negative.")
  }
  
  conflicts <- audio_files |>
    distinct(source_id, url, file_name, mime_type, duration_seconds) |>
    count(source_id, name = "n_versions") |>
    filter(n_versions > 1L)
  
  if (nrow(conflicts) > 0) {
    stop("Conflicting data for audio source ID: ",
         paste(conflicts$source_id, collapse = ", "))
  }
  
  audio_files |>
    distinct(source_id, .keep_all = TRUE) |>
    arrange(source_id) |>
    select(source_id, id, url, file_name, mime_type, duration_seconds)
}

split_wordpress_content <- function(content) {
  content <- as.character(content)
  
  more_pattern <- "<!--more(?:\\s+.*?)?-->"
  
  marker_count <- str_count(replace_na(content, ""),
                            regex(more_pattern, ignore_case = TRUE))
  
  if (any(marker_count > 1L)) {
    stop("Multiple <!--more--> markers found in WordPress content")
  }
  
  has_more <- marker_count == 1L
  
  description <- if_else(has_more, str_extract(content, regex(
    paste0("^.*?(?=", more_pattern, ")"),
    ignore_case = TRUE,
    dotall = TRUE
  )), NA_character_)
  
  body <- if_else(has_more, str_replace(content, regex(
    paste0("^.*?", more_pattern),
    ignore_case = TRUE,
    dotall = TRUE
  ), ""), content)
  
  tibble(description = clean_optional_text(description),
         content = clean_optional_text(body))
}

build_content_json <- function(content_raw) {
  content_raw <- clean_optional_text(content_raw)
  
  map_chr(content_raw, \(value) {
    if (is.na(value)) {
      return(NA_character_)
    }
    
    toJSON(list(format = "html", value = value), auto_unbox = TRUE)
  })
}

convert_wordpress_captions <- function(content) {
  content <- as.character(content)
  
  map_chr(content, \(value) {
    if (is.na(value)) {
      return(NA_character_)
    }
    
    open_count <- str_count(value, regex("\\[caption\\b", ignore_case = TRUE))
    
    close_count <- str_count(value, regex("\\[/caption\\]", ignore_case = TRUE))
    
    if (open_count != close_count) {
      stop("Unbalanced WordPress caption shortcode")
    }
    
    value |>
      str_replace_all(regex("\\[caption\\b([^\\]]*)\\]", ignore_case = TRUE),
                      \(opening) {
                        align <- str_match(opening,
                                           regex("\\balign=[\"']([^\"']+)[\"']", ignore_case = TRUE))[, 2]
                        
                        if (is.na(align)) {
                          align <- "alignnone"
                        }
                        
                        if (!align %in% c("alignnone", "alignleft", "alignright", "aligncenter")) {
                          stop("Unexpected WordPress caption alignment: ", align)
                        }
                        
                        paste0('<figure class="wp-caption ', align, '">')
                      }) |>
      str_replace_all(regex("\\[/caption\\]", ignore_case = TRUE), "</figure>")
  })
}

normalize_wordpress_html <- function(content) {
  content |>
    clean_optional_text() |>
    convert_wordpress_captions()
}

prepare_wordpress_content <- function(content) {
  parts <- split_wordpress_content(content)
  
  parts |>
    mutate(content = normalize_wordpress_html(content))
}

prepare_wp_episode_text_rows <- function(wp_rows) {
  required_columns <- c("post_id",
                        "locale",
                        "translation_group_id",
                        "original_post_id",
                        "post_content")
  
  missing_columns <- setdiff(required_columns, names(wp_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required WordPress episode text columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  replay_rows <- wp_rows |>
    filter(!is.na(original_post_id))
  
  if (nrow(replay_rows) > 0) {
    stop(
      "Replay posts must not contribute episode text: ",
      paste(replay_rows$post_id, collapse = ", ")
    )
  }
  
  if (any(is.na(wp_rows$translation_group_id))) {
    stop("WordPress episode is missing translation_group_id")
  }
  
  if (any(is.na(wp_rows$locale) | wp_rows$locale == "")) {
    stop("WordPress episode is missing locale")
  }
  
  prepared_content <- prepare_wordpress_content(wp_rows$post_content)
  
  wp_rows |>
    transmute(episode_source_key = translation_group_id, locale = as.character(locale)) |>
    bind_cols(prepared_content)
}

#  POSTS / ARTICLES DOMAIN ----
build_posts <- function(post_rows) {
  required_columns <- c("post_source_key", "canonical_slug")
  
  missing_columns <- setdiff(required_columns, names(post_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required post columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  posts <- post_rows |>
    mutate(canonical_slug = str_trim(canonical_slug))
  
  if (any(is.na(posts$post_source_key))) {
    stop("post_source_key must not be missing")
  }
  
  if (any(is.na(posts$canonical_slug) |
          posts$canonical_slug == "")) {
    stop("canonical_slug must not be missing or empty")
  }
  
  if (any(nchar(posts$canonical_slug) > 190)) {
    stop("canonical_slug exceeds posts.slug maximum length of 190")
  }
  
  conflicting_slugs <- posts |>
    distinct(post_source_key, canonical_slug) |>
    count(post_source_key, name = "slug_count") |>
    filter(slug_count > 1)
  
  if (nrow(conflicting_slugs) > 0) {
    stop("A post_source_key maps to multiple canonical slugs")
  }
  
  duplicate_slugs <- posts |>
    distinct(post_source_key, canonical_slug) |>
    count(canonical_slug, name = "post_count") |>
    filter(post_count > 1)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Multiple posts map to the same canonical slug")
  }
  
  posts |>
    distinct(post_source_key, canonical_slug) |>
    transmute(id = post_article_uuid(post_source_key), slug = canonical_slug)
}

build_post_texts <- function(post_rows) {
  required_columns <- c("post_source_key", "locale", "title", "description", "content")
  
  missing_columns <- setdiff(required_columns, names(post_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required post text columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  post_texts <- post_rows |>
    mutate(
      locale = str_trim(locale),
      title = str_trim(title),
      description = clean_optional_text(description)
    )
  
  if (any(nchar(post_texts$locale) > 10)) {
    stop("locale exceeds post_texts.locale maximum length of 10")
  }
  
  if (any(is.na(post_texts$post_source_key))) {
    stop("post_source_key must not be missing")
  }
  
  if (any(is.na(post_texts$locale) | post_texts$locale == "")) {
    stop("locale must not be missing or empty")
  }
  
  if (any(is.na(post_texts$title) | post_texts$title == "")) {
    stop("title must not be missing or empty")
  }
  
  if (any(nchar(post_texts$title) > 255)) {
    stop("title exceeds post_texts.title maximum length of 255")
  }
  
  duplicate_locales <- post_texts |>
    count(post_source_key, locale, name = "row_count") |>
    filter(row_count > 1)
  
  if (nrow(duplicate_locales) > 0) {
    stop("A post has multiple text rows for the same locale")
  }
  
  post_texts |>
    transmute(
      post_id = post_article_uuid(post_source_key),
      locale,
      title,
      description,
      content_raw = clean_optional_text(content),
      content = build_content_json(content_raw)
    )
}

build_categories <- function(category_rows) {
  required_columns <- c("category_source_key", "canonical_slug", "canonical_name")
  
  missing_columns <- setdiff(required_columns, names(category_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required category columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  categories <- category_rows |>
    mutate(
      canonical_slug = str_trim(canonical_slug),
      canonical_name = str_trim(canonical_name)
    )
  
  if (any(is.na(categories$category_source_key))) {
    stop("category_source_key must not be missing")
  }
  
  conflicting_categories <- categories |>
    distinct(category_source_key, canonical_slug, canonical_name) |>
    count(category_source_key, name = "definition_count") |>
    filter(definition_count > 1)
  
  if (nrow(conflicting_categories) > 0) {
    stop("A category_source_key maps to multiple category definitions")
  }
  
  duplicate_slugs <- categories |>
    distinct(category_source_key, canonical_slug) |>
    count(canonical_slug, name = "category_count") |>
    filter(category_count > 1)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Multiple categories map to the same canonical slug")
  }
  
  if (any(is.na(categories$canonical_slug) | categories$canonical_slug == "")) {
    stop("canonical_slug must not be missing or empty")
  }
  
  if (any(is.na(categories$canonical_name) | categories$canonical_name == "")) {
    stop("canonical_name must not be missing or empty")
  }
  
  if (any(nchar(categories$canonical_slug) > 190)) {
    stop("canonical_slug exceeds categories.slug maximum length of 190")
  }
  
  if (any(nchar(categories$canonical_name) > 255)) {
    stop("canonical_name exceeds categories.name maximum length of 255")
  }
  
  categories |>
    distinct(category_source_key, canonical_slug, canonical_name) |>
    arrange(category_source_key) |>
    mutate(id = row_number()) |>
    select(id, slug = canonical_slug, name = canonical_name)
}

build_tags <- function(tag_rows) {
  required_columns <- c("tag_source_key", "canonical_slug", "canonical_name")
  
  missing_columns <- setdiff(required_columns, names(tag_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required tag columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  tags <- tag_rows |>
    mutate(
      canonical_slug = str_trim(canonical_slug),
      canonical_name = str_trim(canonical_name)
    )
  
  if (any(is.na(tags$tag_source_key))) {
    stop("tag_source_key must not be missing")
  }
  
  if (any(is.na(tags$canonical_slug) | tags$canonical_slug == "")) {
    stop("canonical_slug must not be missing or empty")
  }
  
  if (any(is.na(tags$canonical_name) | tags$canonical_name == "")) {
    stop("canonical_name must not be missing or empty")
  }
  
  if (any(nchar(tags$canonical_slug) > 190)) {
    stop("canonical_slug exceeds tags.slug maximum length of 190")
  }
  
  if (any(nchar(tags$canonical_name) > 255)) {
    stop("canonical_name exceeds tags.name maximum length of 255")
  }
  
  conflicting_tags <- tags |>
    distinct(tag_source_key, canonical_slug, canonical_name) |>
    count(tag_source_key, name = "definition_count") |>
    filter(definition_count > 1)
  
  if (nrow(conflicting_tags) > 0) {
    stop("A tag_source_key maps to multiple tag definitions")
  }
  
  duplicate_slugs <- tags |>
    distinct(tag_source_key, canonical_slug) |>
    count(canonical_slug, name = "tag_count") |>
    filter(tag_count > 1)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Multiple tags map to the same canonical slug")
  }
  
  tags |>
    distinct(tag_source_key, canonical_slug, canonical_name) |>
    arrange(tag_source_key) |>
    mutate(id = row_number()) |>
    select(id, slug = canonical_slug, name = canonical_name)
}

build_category_id_lookup <- function(category_rows) {
  # Reuse build_categories() validation and deterministic ordering.
  build_categories(category_rows)
  
  category_rows |>
    distinct(category_source_key) |>
    arrange(category_source_key) |>
    mutate(category_id = row_number())
}

build_tag_id_lookup <- function(tag_rows) {
  # Reuse build_tags() validation and deterministic ordering.
  build_tags(tag_rows)
  
  tag_rows |>
    distinct(tag_source_key) |>
    arrange(tag_source_key) |>
    mutate(tag_id = row_number())
}

build_post_categories <- function(post_category_rows, category_rows) {
  required_columns <- c("post_source_key", "category_source_key", "position")
  
  missing_columns <- setdiff(required_columns, names(post_category_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required post-category columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  relations <- post_category_rows
  
  if (any(is.na(relations$post_source_key))) {
    stop("post_source_key must not be missing")
  }
  
  if (any(is.na(relations$category_source_key))) {
    stop("category_source_key must not be missing")
  }
  
  if (!is.numeric(relations$position) ||
      any(
        is.na(relations$position) |
        !is.finite(relations$position) |
        relations$position != floor(relations$position) |
        relations$position < 1 |
        relations$position > 65535
      )) {
    stop("position must be an integer between 1 and 65535")
  }
  
  relations <- relations |>
    distinct(post_source_key, category_source_key, position)
  
  conflicting_relations <- relations |>
    count(post_source_key, category_source_key, name = "position_count") |>
    filter(position_count > 1)
  
  if (nrow(conflicting_relations) > 0) {
    stop("A post-category relation maps to multiple positions")
  }
  
  duplicate_positions <- relations |>
    count(post_source_key, position, name = "category_count") |>
    filter(category_count > 1)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple categories map to the same post position")
  }
  
  category_lookup <- build_category_id_lookup(category_rows)
  
  missing_categories <- relations |>
    distinct(category_source_key) |>
    anti_join(category_lookup, by = "category_source_key")
  
  if (nrow(missing_categories) > 0) {
    stop("post-category relation references an unknown category_source_key")
  }
  
  relations |>
    left_join(category_lookup, by = "category_source_key") |>
    transmute(
      post_id = post_article_uuid(post_source_key),
      category_id,
      position = as.integer(position)
    ) |>
    arrange(post_id, position)
}

build_post_tags <- function(post_tag_rows, tag_rows) {
  required_columns <- c("post_source_key", "tag_source_key", "position")
  
  missing_columns <- setdiff(required_columns, names(post_tag_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required post-tag columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  relations <- post_tag_rows
  
  if (any(is.na(relations$post_source_key))) {
    stop("post_source_key must not be missing")
  }
  
  if (any(is.na(relations$tag_source_key))) {
    stop("tag_source_key must not be missing")
  }
  
  if (!is.numeric(relations$position) ||
      any(
        is.na(relations$position) |
        !is.finite(relations$position) |
        relations$position != floor(relations$position) |
        relations$position < 1 |
        relations$position > 65535
      )) {
    stop("position must be an integer between 1 and 65535")
  }
  
  relations <- relations |>
    distinct(post_source_key, tag_source_key, position)
  
  conflicting_relations <- relations |>
    count(post_source_key, tag_source_key, name = "position_count") |>
    filter(position_count > 1)
  
  if (nrow(conflicting_relations) > 0) {
    stop("A post-tag relation maps to multiple positions")
  }
  
  duplicate_positions <- relations |>
    count(post_source_key, position, name = "tag_count") |>
    filter(tag_count > 1)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple tags map to the same post position")
  }
  
  tag_lookup <- build_tag_id_lookup(tag_rows)
  
  missing_tags <- relations |>
    distinct(tag_source_key) |>
    anti_join(tag_lookup, by = "tag_source_key")
  
  if (nrow(missing_tags) > 0) {
    stop("post-tag relation references an unknown tag_source_key")
  }
  
  relations |>
    left_join(tag_lookup, by = "tag_source_key") |>
    transmute(post_id = post_article_uuid(post_source_key),
              tag_id,
              position = as.integer(position)) |>
    arrange(post_id, position)
}

# CONCERTPODIUM / RECORDING DOMAIN ----

build_venues <- function(venue_rows) {
  required_columns <- c("venue_source_key",
                        "name",
                        "city",
                        "address",
                        "country_code")
  
  missing_columns <- setdiff(required_columns, names(venue_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required venue columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  venues <- venue_rows |>
    mutate(
      name = str_trim(name),
      city = clean_optional_text(city),
      address = clean_optional_text(address),
      country_code = clean_optional_text(country_code),
      country_code = if_else(
        is.na(country_code),
        NA_character_,
        str_to_upper(country_code)
      )
    )
  
  if (any(is.na(venues$venue_source_key))) {
    stop("venue_source_key must not be missing")
  }
  
  if (any(is.na(venues$name) | venues$name == "")) {
    stop("venue name must not be missing or empty")
  }
  
  if (any(nchar(venues$name) > 255)) {
    stop("venue name exceeds venues.name maximum length of 255")
  }
  
  if (any(!is.na(venues$city) & nchar(venues$city) > 255)) {
    stop("venue city exceeds venues.city maximum length of 255")
  }
  
  if (any(!is.na(venues$address) & nchar(venues$address) > 500)) {
    stop("venue address exceeds venues.address maximum length of 500")
  }
  
  if (any(!is.na(venues$country_code) &
          !str_detect(venues$country_code, "^[A-Z]{2}$"))) {
    stop("venue country_code must contain exactly two ASCII letters")
  }
  
  conflicting_venues <- venues |>
    distinct(venue_source_key, name, city, address, country_code) |>
    count(venue_source_key, name = "definition_count") |>
    filter(definition_count > 1)
  
  if (nrow(conflicting_venues) > 0) {
    stop("A venue_source_key maps to multiple venue definitions")
  }
  
  venues |>
    distinct(venue_source_key, name, city, address, country_code) |>
    transmute(id = venue_uuid(venue_source_key), name, city, address, country_code)
}


build_recording_collections <- function(recording_collection_rows) {
  required_columns <- c("recording_collection_source_key", "canonical_slug")
  
  missing_columns <- setdiff(required_columns, names(recording_collection_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required recording collection columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  collections <- recording_collection_rows |>
    mutate(canonical_slug = str_trim(canonical_slug))
  
  if (any(is.na(collections$recording_collection_source_key))) {
    stop("recording_collection_source_key must not be missing")
  }
  
  if (any(is.na(collections$canonical_slug) |
          collections$canonical_slug == "")) {
    stop("canonical_slug must not be missing or empty")
  }
  
  if (any(nchar(collections$canonical_slug) > 190)) {
    stop("canonical_slug exceeds recording_collections.slug maximum length of 190")
  }
  
  conflicting_slugs <- collections |>
    distinct(recording_collection_source_key, canonical_slug) |>
    count(recording_collection_source_key, name = "slug_count") |>
    filter(slug_count > 1)
  
  if (nrow(conflicting_slugs) > 0) {
    stop("A recording_collection_source_key maps to multiple canonical slugs")
  }
  
  duplicate_slugs <- collections |>
    distinct(recording_collection_source_key, canonical_slug) |>
    count(canonical_slug, name = "collection_count") |>
    filter(collection_count > 1)
  
  if (nrow(duplicate_slugs) > 0) {
    stop("Multiple recording collections map to the same canonical slug")
  }
  
  collections |>
    distinct(recording_collection_source_key, canonical_slug) |>
    transmute(id = recording_collection_uuid(recording_collection_source_key),
              slug = canonical_slug)
}


build_recording_collection_texts <- function(recording_collection_rows) {
  required_columns <- c("recording_collection_source_key",
                        "locale",
                        "title",
                        "description")
  
  missing_columns <- setdiff(required_columns, names(recording_collection_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required recording collection text columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  texts <- recording_collection_rows |>
    mutate(
      locale = str_trim(locale),
      title = str_trim(title),
      description = clean_optional_text(description)
    )
  
  if (any(is.na(texts$recording_collection_source_key))) {
    stop("recording_collection_source_key must not be missing")
  }
  
  if (any(is.na(texts$locale) | texts$locale == "")) {
    stop("locale must not be missing or empty")
  }
  
  if (any(nchar(texts$locale) > 10)) {
    stop("locale exceeds recording_collection_texts.locale maximum length of 10")
  }
  
  if (any(is.na(texts$title) | texts$title == "")) {
    stop("title must not be missing or empty")
  }
  
  if (any(nchar(texts$title) > 255)) {
    stop("title exceeds recording_collection_texts.title maximum length of 255")
  }
  
  duplicate_locales <- texts |>
    count(recording_collection_source_key, locale, name = "row_count") |>
    filter(row_count > 1)
  
  if (nrow(duplicate_locales) > 0) {
    stop("A recording collection has multiple text rows for the same locale")
  }
  
  texts |>
    transmute(
      recording_collection_id = recording_collection_uuid(recording_collection_source_key),
      locale,
      title,
      description
    )
}

build_recording_collection_artists <- function(recording_collection_artist_rows) {
  required_columns <- c("recording_collection_source_key",
                        "artist_source_id",
                        "position")
  
  missing_columns <- setdiff(required_columns, names(recording_collection_artist_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required recording collection artist columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  relations <- recording_collection_artist_rows
  
  if (any(is.na(relations$recording_collection_source_key))) {
    stop("recording_collection_source_key must not be missing")
  }
  
  if (any(is.na(relations$artist_source_id))) {
    stop("artist_source_id must not be missing")
  }
  
  if (!is.numeric(relations$position) ||
      any(
        is.na(relations$position) |
        !is.finite(relations$position) |
        relations$position != floor(relations$position) |
        relations$position < 1 |
        relations$position > 65535
      )) {
    stop("position must be an integer between 1 and 65535")
  }
  
  relations <- relations |>
    distinct(recording_collection_source_key,
             artist_source_id,
             position)
  
  conflicting_artists <- relations |>
    count(recording_collection_source_key, artist_source_id, name = "position_count") |>
    filter(position_count > 1)
  
  if (nrow(conflicting_artists) > 0) {
    stop("A recording collection artist maps to multiple positions")
  }
  
  duplicate_positions <- relations |>
    count(recording_collection_source_key, position, name = "artist_count") |>
    filter(artist_count > 1)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple artists map to the same recording collection position")
  }
  
  relations |>
    transmute(
      recording_collection_id = recording_collection_uuid(recording_collection_source_key),
      artist_id = artist_uuid(artist_source_id),
      position = as.integer(position)
    ) |>
    arrange(recording_collection_id, position)
}


build_recorded_concerts <- function(recorded_concert_rows) {
  required_columns <- c(
    "recorded_concert_source_key",
    "recording_collection_source_key",
    "venue_source_key",
    "position"
  )
  
  missing_columns <- setdiff(required_columns, names(recorded_concert_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required recorded concert columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  concerts <- recorded_concert_rows
  
  if (any(is.na(concerts$recorded_concert_source_key))) {
    stop("recorded_concert_source_key must not be missing")
  }
  
  if (any(is.na(concerts$recording_collection_source_key))) {
    stop("recording_collection_source_key must not be missing")
  }
  
  if (any(is.na(concerts$venue_source_key))) {
    stop("venue_source_key must not be missing")
  }
  
  if (!is.numeric(concerts$position) ||
      any(
        is.na(concerts$position) |
        !is.finite(concerts$position) |
        concerts$position != floor(concerts$position) |
        concerts$position < 1 |
        concerts$position > 65535
      )) {
    stop("position must be an integer between 1 and 65535")
  }
  
  concerts <- concerts |>
    distinct(
      recorded_concert_source_key,
      recording_collection_source_key,
      venue_source_key,
      position
    )
  
  conflicting_concerts <- concerts |>
    count(recorded_concert_source_key, name = "definition_count") |>
    filter(definition_count > 1)
  
  if (nrow(conflicting_concerts) > 0) {
    stop("A recorded_concert_source_key maps to multiple recorded concert definitions")
  }
  
  duplicate_positions <- concerts |>
    count(recording_collection_source_key, position, name = "concert_count") |>
    filter(concert_count > 1)
  
  if (nrow(duplicate_positions) > 0) {
    stop("Multiple recorded concerts map to the same recording collection position")
  }
  
  concerts |>
    transmute(
      id = recorded_concert_uuid(recorded_concert_source_key),
      recording_collection_id = recording_collection_uuid(recording_collection_source_key),
      venue_id = venue_uuid(venue_source_key),
      position = as.integer(position)
    ) |>
    arrange(recording_collection_id, position)
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

# test_episodes ----
test_episode_rows <- tibble(
  episode_source_key = c(223729, 223729),
  program_term_id = c(17016, 17018),
  locale = c("nl", "en"),
  post_name = c(
    "concertzender-live-2026-02-19",
    "concertzender-live-2026-02-19-en"
  ),
  image_source_id = c(90101, 90101),
  audio_source_id = c(90201, 90201),
  mood_wave = c(2, 2),
  mood_color = c(NA, 4),
  mood_tempo = c(5, 5),
  mood_intensity = c(3, 3)
)

test_episodes <- build_episodes(
  test_episode_rows,
  test_program_term_map,
  test_images,
  test_audio_files
)

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

# test_episode_texts

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

# test_genres

# test_genre_texts ----
test_genre_texts <- build_genre_texts(
  test_compat_genres,
  test_genres
)

# test_genre_texts

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

# test_program_genres

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

# test_subgenres

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

# test_episode_subgenres

# test_artist_rows ----
test_artist_rows <- tibble(
  artist_source_id = c(
    70101,
    70102,
    70101
  ),
  artist_name = c(
    "John Coltrane",
    "  Alice   Coltrane ",
    "John Coltrane"
  )
)

test_artists <- build_artists(
  test_artist_rows
)

# test_artists

# test_episode_artist_rows ----
test_episode_artist_rows <- tibble(
  episode_source_key = c(
    223729,
    223729,
    223729
  ),
  artist_source_id = c(
    70101,
    70102,
    70101
  ),
  position = c(
    1,
    2,
    1
  )
)

test_episode_artists <- build_episode_artists(
  test_episode_artist_rows,
  test_episodes,
  test_artists
)

# test_episode_artists

# test_editor_rows ----
test_editor_rows <- tibble(
  editor_source_id = c(
    80101,
    80102,
    80101
  ),
  editor_name = c(
    "Jan de Vries",
    "  Maria   Jansen ",
    "Jan de Vries"
  )
)

test_editors <- build_editors(
  test_editor_rows
)

# test_episode_editor_rows ----
test_episode_editor_rows <- tibble(
  episode_source_key = c(
    223729,
    223729,
    223729
  ),
  editor_source_id = c(
    80101,
    80102,
    80101
  ),
  role = c(
    "producer",
    "producer_presenter",
    "producer"
  ),
  position = c(
    1,
    2,
    1
  )
)

test_episode_editors <- build_episode_editors(
  test_episode_editor_rows,
  test_episodes,
  test_editors
)

# test_image_rows ----
test_image_rows <- tibble(
  image_source_id = c(
    90101,
    90102,
    90101
  ),
  url = c(
    "https://example.org/uploads/coltrane.jpg",
    "https://example.org/uploads/concert.jpg",
    "https://example.org/uploads/coltrane.jpg"
  ),
  alt_text = c(
    "John Coltrane",
    "",
    "John Coltrane"
  ),
  mime_type = c(
    "image/jpeg",
    "image/jpeg",
    "image/jpeg"
  ),
  width_px = c(
    1200,
    1600,
    1200
  ),
  height_px = c(
    800,
    900,
    800
  )
)

test_images <- build_images(
  test_image_rows
)

# test_audio_rows ----
test_audio_rows <- tibble(
  audio_source_id = c(
    90201,
    90202,
    90201
  ),
  url = c(
    "https://example.org/audio/episode-1.mp3",
    "https://example.org/audio/episode-2.mp3",
    "https://example.org/audio/episode-1.mp3"
  ),
  file_name = c(
    "episode-1.mp3",
    "",
    "episode-1.mp3"
  ),
  mime_type = c(
    "audio/mpeg",
    "audio/mpeg",
    "audio/mpeg"
  ),
  duration_seconds = c(
    3599.125,
    NA,
    3599.125
  )
)

test_audio_files <- build_audio_files(
  test_audio_rows
)

# test_post_rows ----
test_post_rows <- tibble(
  post_source_key = c(48123, 48123),
  locale = c("nl", "en"),
  wp_post_id = c(812001, 812002),
  post_name = c(
    "nieuwe-serie-op-de-concertzender",
    "new-series-on-concertzender"
  ),
  canonical_slug = c(
    "nieuwe-serie-op-de-concertzender",
    "nieuwe-serie-op-de-concertzender"
  )
)

test_posts <- build_posts(test_post_rows)

# test_duplicate_post_slugs ----
test_duplicate_post_slugs <- tibble(
  post_source_key = c(48123, 48124),
  canonical_slug = c(
    "nieuwe-serie-op-de-concertzender",
    "nieuwe-serie-op-de-concertzender"
  )
)

# this will fail as expected:
# build_posts(test_duplicate_post_slugs)

# test_post_texts ----
test_post_text_rows <- tibble(
  post_source_key = c(48123, 48123),
  locale = c("nl", "en"),
  title = c(
    "Nieuwe serie op de Concertzender",
    "New series on Concertzender"
  ),
  description = c(
    "Een nieuwe serie begint binnenkort.",
    NA_character_
  ),
  content = c(
    "<p>Nederlandse uitgebreide inhoud.</p>",
    "<p>English extended content.</p>"
  )
)

test_post_texts <- build_post_texts(test_post_text_rows)

test_duplicate_post_text_locale <- tibble(
  post_source_key = c(48123, 48123),
  locale = c("nl", "nl"),
  title = c(
    "Eerste titel",
    "Tweede titel"
  ),
  description = c(
    NA_character_,
    NA_character_
  ),
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_duplicate_post_text_locale)

test_missing_post_title <- tibble(
  post_source_key = 48123,
  locale = "nl",
  title = NA_character_,
  description = NA_character_,
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_missing_post_title)

test_long_post_title <- tibble(
  post_source_key = 48123,
  locale = "nl",
  title = str_dup("x", 256),
  description = NA_character_,
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_long_post_title)

test_missing_post_locale <- tibble(
  post_source_key = 48123,
  locale = NA_character_,
  title = "Nieuwe serie op de Concertzender",
  description = NA_character_,
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_missing_post_locale)

test_long_post_locale <- tibble(
  post_source_key = 48123,
  locale = "abcdefghijk",
  title = "Nieuwe serie op de Concertzender",
  description = NA_character_,
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_long_post_locale)

test_missing_post_source_key <- tibble(
  post_source_key = NA_real_,
  locale = "nl",
  title = "Nieuwe serie op de Concertzender",
  description = NA_character_,
  content = NA_character_
)

# this will fail as expected:
# build_post_texts(test_missing_post_source_key)

# test_category_rows ----
test_category_rows <- tibble(
  category_source_key = c(27, 12, 27),
  canonical_slug = c(
    "nieuws",
    "achtergronden",
    "nieuws"
  ),
  canonical_name = c(
    "Nieuws",
    "Achtergronden",
    "Nieuws"
  )
)

test_categories <- build_categories(test_category_rows)

test_conflicting_category <- tibble(
  category_source_key = c(27, 27),
  canonical_slug = c("nieuws", "news"),
  canonical_name = c("Nieuws", "News")
)

# this will fail as expected:
# build_categories(test_conflicting_category)

test_duplicate_category_slug <- tibble(
  category_source_key = c(27, 28),
  canonical_slug = c("nieuws", "nieuws"),
  canonical_name = c("Nieuws", "Nieuws archief")
)

# this will fail as expected:
# build_categories(test_duplicate_category_slug)

test_missing_category_slug <- tibble(
  category_source_key = 27,
  canonical_slug = NA_character_,
  canonical_name = "Nieuws"
)

# this will fail as expected:
# build_categories(test_missing_category_slug)

test_missing_category_name <- tibble(
  category_source_key = 27,
  canonical_slug = "nieuws",
  canonical_name = NA_character_
)

# this will fail as expected:
# build_categories(test_missing_category_name)

test_long_category_slug <- tibble(
  category_source_key = 27,
  canonical_slug = str_dup("x", 191),
  canonical_name = "Nieuws"
)

# this will fail as expected:
# build_categories(test_long_category_slug)

test_long_category_name <- tibble(
  category_source_key = 27,
  canonical_slug = "nieuws",
  canonical_name = str_dup("x", 256)
)

# this will fail as expected:
# build_categories(test_long_category_name)

test_missing_category_source_key <- tibble(
  category_source_key = NA_real_,
  canonical_slug = "nieuws",
  canonical_name = "Nieuws"
)

# this will fail as expected:
# build_categories(test_missing_category_source_key)

# test_tags ----
# Positive mapping: duplicate source rows collapse deterministically.
test_tag_rows <- tibble(
  tag_source_key = c(42, 15, 42),
  canonical_slug = c(
    "jazz",
    "interview",
    "jazz"
  ),
  canonical_name = c(
    "Jazz",
    "Interview",
    "Jazz"
  )
)

test_tags <- build_tags(test_tag_rows)

test_tags


# One source identity cannot have conflicting definitions.
tryCatch(
  build_tags(
    tibble(
      tag_source_key = c(42, 42),
      canonical_slug = c("jazz", "jazz-music"),
      canonical_name = c("Jazz", "Jazz Music")
    )
  ),
  error = function(e) message(e$message)
)


# Different tags cannot share a target slug.
tryCatch(
  build_tags(
    tibble(
      tag_source_key = c(42, 43),
      canonical_slug = c("jazz", "jazz"),
      canonical_name = c("Jazz", "Jazz archief")
    )
  ),
  error = function(e) message(e$message)
)


# Missing slug.
tryCatch(
  build_tags(
    tibble(
      tag_source_key = 42,
      canonical_slug = NA_character_,
      canonical_name = "Jazz"
    )
  ),
  error = function(e) message(e$message)
)


# Missing name.
tryCatch(
  build_tags(
    tibble(
      tag_source_key = 42,
      canonical_slug = "jazz",
      canonical_name = NA_character_
    )
  ),
  error = function(e) message(e$message)
)


# Slug exceeds varchar(190).
tryCatch(
  build_tags(
    tibble(
      tag_source_key = 42,
      canonical_slug = str_dup("x", 191),
      canonical_name = "Jazz"
    )
  ),
  error = function(e) message(e$message)
)


# Name exceeds varchar(255).
tryCatch(
  build_tags(
    tibble(
      tag_source_key = 42,
      canonical_slug = "jazz",
      canonical_name = str_dup("x", 256)
    )
  ),
  error = function(e) message(e$message)
)


# Missing source identity.
tryCatch(
  build_tags(
    tibble(
      tag_source_key = NA_real_,
      canonical_slug = "jazz",
      canonical_name = "Jazz"
    )
  ),
  error = function(e) message(e$message)
)

test_post_category_rows <- tibble(
  post_source_key = c(48123, 48123, 48123),
  category_source_key = c(12, 12, 27),
  position = c(1, 1, 2)
)

test_post_categories <- build_post_categories(
  test_post_category_rows,
  test_category_rows
)

# test_post_categories


test_post_tag_rows <- tibble(
  post_source_key = c(48123, 48123, 48123),
  tag_source_key = c(15, 15, 42),
  position = c(1, 1, 2)
)

test_post_tags <- build_post_tags(
  test_post_tag_rows,
  test_tag_rows
)

# test_post_tags

# Same category, conflicting positions.
tryCatch(
  build_post_categories(
    tibble(
      post_source_key = c(48123, 48123),
      category_source_key = c(12, 12),
      position = c(1, 2)
    ),
    test_category_rows
  ),
  error = function(e) message(e$message)
)


# Two categories occupying the same position.
tryCatch(
  build_post_categories(
    tibble(
      post_source_key = c(48123, 48123),
      category_source_key = c(12, 27),
      position = c(1, 1)
    ),
    test_category_rows
  ),
  error = function(e) message(e$message)
)


# Unknown category.
tryCatch(
  build_post_categories(
    tibble(
      post_source_key = 48123,
      category_source_key = 999,
      position = 1
    ),
    test_category_rows
  ),
  error = function(e) message(e$message)
)


# Same tag, conflicting positions.
tryCatch(
  build_post_tags(
    tibble(
      post_source_key = c(48123, 48123),
      tag_source_key = c(15, 15),
      position = c(1, 2)
    ),
    test_tag_rows
  ),
  error = function(e) message(e$message)
)


# Two tags occupying the same position.
tryCatch(
  build_post_tags(
    tibble(
      post_source_key = c(48123, 48123),
      tag_source_key = c(15, 42),
      position = c(1, 1)
    ),
    test_tag_rows
  ),
  error = function(e) message(e$message)
)


# Unknown tag.
tryCatch(
  build_post_tags(
    tibble(
      post_source_key = 48123,
      tag_source_key = 999,
      position = 1
    ),
    test_tag_rows
  ),
  error = function(e) message(e$message)
)


# Invalid relation position.
tryCatch(
  build_post_tags(
    tibble(
      post_source_key = 48123,
      tag_source_key = 15,
      position = 0
    ),
    test_tag_rows
  ),
  error = function(e) message(e$message)
)

# test venues ----
test_venue_rows <- tibble(
  venue_source_key = c(301, 302, 301),
  name = c(
    "Muziekgebouw aan 't IJ",
    "TivoliVredenburg",
    "Muziekgebouw aan 't IJ"
  ),
  city = c(
    "Amsterdam",
    "Utrecht",
    "Amsterdam"
  ),
  address = c(
    "Piet Heinkade 1",
    "Vredenburgkade 11",
    "Piet Heinkade 1"
  ),
  country_code = c("nl", "NL", "nl")
)

test_venues <- build_venues(test_venue_rows)

# test_recording_collections ----
test_recording_collection_rows <- tibble(
  recording_collection_source_key = c(74839, 74839),
  canonical_slug = c(
    "nieuw-ensemble-het-verfijnde-oor-2",
    "nieuw-ensemble-het-verfijnde-oor-2"
  ),
  locale = c("nl", "en"),
  title = c(
    "Nieuw Ensemble: het verfijnde oor 2",
    "Nieuw Ensemble: the refined ear 2"
  ),
  description = c(
    "Werken van o.a. Vasco Medonca en Wilbert Bulsink.",
    "Works by, among others, Vasco Medonca and Wilbert Bulsink."
  )
)

test_recording_collections <- build_recording_collections(
  test_recording_collection_rows
)

test_recording_collection_texts <-
  build_recording_collection_texts(
    test_recording_collection_rows
  )

# test_recording_collections
# test_recording_collection_texts

# Conflicting definition for one venue identity.
tryCatch(
  build_venues(
    tibble(
      venue_source_key = c(301, 301),
      name = c("Venue A", "Venue B"),
      city = c("Amsterdam", "Amsterdam"),
      address = c(NA_character_, NA_character_),
      country_code = c("NL", "NL")
    )
  ),
  error = function(e) message(e$message)
)


# Invalid country code.
tryCatch(
  build_venues(
    tibble(
      venue_source_key = 301,
      name = "Venue A",
      city = "Amsterdam",
      address = NA_character_,
      country_code = "NLD"
    )
  ),
  error = function(e) message(e$message)
)


# One collection identity cannot resolve to two slugs.
tryCatch(
  build_recording_collections(
    tibble(
      recording_collection_source_key = c(74839, 74839),
      canonical_slug = c("slug-one", "slug-two")
    )
  ),
  error = function(e) message(e$message)
)


# Two collections cannot share one target slug.
tryCatch(
  build_recording_collections(
    tibble(
      recording_collection_source_key = c(74839, 74840),
      canonical_slug = c("same-slug", "same-slug")
    )
  ),
  error = function(e) message(e$message)
)


# One localized text row per collection/locale.
tryCatch(
  build_recording_collection_texts(
    tibble(
      recording_collection_source_key = c(74839, 74839),
      locale = c("nl", "nl"),
      title = c("Titel A", "Titel B"),
      description = c(NA_character_, NA_character_)
    )
  ),
  error = function(e) message(e$message)
)

# test_recording_collection_artists ----
test_recording_collection_artist_rows <- tibble(
  recording_collection_source_key = c(
    74839, 74839, 74839
  ),
  artist_source_id = c(
    "artist-a",
    "artist-a",
    "artist-b"
  ),
  position = c(1, 1, 2)
)

test_recording_collection_artists <-
  build_recording_collection_artists(
    test_recording_collection_artist_rows
  )

# test_recording_collection_artists


test_recorded_concert_rows <- tibble(
  recorded_concert_source_key = c(
    "74839-1",
    "74839-1",
    "74839-2"
  ),
  recording_collection_source_key = c(
    74839, 74839, 74839
  ),
  venue_source_key = c(
    301, 301, 302
  ),
  position = c(1, 1, 2)
)

test_recorded_concerts <- build_recorded_concerts(
  test_recorded_concert_rows
)

# test_recorded_concerts
 
# Same artist at two positions.
tryCatch(
  build_recording_collection_artists(
    tibble(
      recording_collection_source_key = c(74839, 74839),
      artist_source_id = c("artist-a", "artist-a"),
      position = c(1, 2)
    )
  ),
  error = function(e) message(e$message)
)


# Two artists at one position.
tryCatch(
  build_recording_collection_artists(
    tibble(
      recording_collection_source_key = c(74839, 74839),
      artist_source_id = c("artist-a", "artist-b"),
      position = c(1, 1)
    )
  ),
  error = function(e) message(e$message)
)


# One recorded-concert identity cannot change definition.
tryCatch(
  build_recorded_concerts(
    tibble(
      recorded_concert_source_key = c("concert-a", "concert-a"),
      recording_collection_source_key = c(74839, 74839),
      venue_source_key = c(301, 302),
      position = c(1, 1)
    )
  ),
  error = function(e) message(e$message)
)


# Two concerts cannot occupy one collection position.
tryCatch(
  build_recorded_concerts(
    tibble(
      recorded_concert_source_key = c("concert-a", "concert-b"),
      recording_collection_source_key = c(74839, 74839),
      venue_source_key = c(301, 302),
      position = c(1, 1)
    )
  ),
  error = function(e) message(e$message)
)


# Invalid position.
tryCatch(
  build_recorded_concerts(
    tibble(
      recorded_concert_source_key = "concert-a",
      recording_collection_source_key = 74839,
      venue_source_key = 301,
      position = 0
    )
  ),
  error = function(e) message(e$message)
)

# split_wordpress_content ----
split_wordpress_content(
  "'The Lions Ear' is de titel van een cd.<!--more--><p>Show notes.</p>"
)

split_wordpress_content(
  "This hour features a new, special CD with early music.<!--more-->"
)

split_wordpress_content(
  "<p>Complete content without a WordPress more marker.</p>"
)

# expected to fail:
# split_wordpress_content(
#   "Intro<!--more--><p>Body</p><!--more--><p>Extra</p>"
# )

test_episode_texts <- build_episode_texts(
  test_episode_text_rows
)

test_caption <- paste0(
  '[caption id="attachment_235463" align="alignright" width="172"]',
  '<img class="wp-image-235463" src="image.jpg" alt="" width="172" height="258" /> ',
  'Fred Jacobs',
  '[/caption]'
)

convert_wordpress_captions(test_caption)

convert_wordpress_captions(
  '[caption id="attachment_1" width="300"]<img src="x.jpg" /> Caption[/caption]'
)

# expected to fail:
# convert_wordpress_captions(
#   '[caption id="attachment_1" align="alignleft"]<img src="x.jpg" /> Caption'
# )

normalize_wordpress_html(
  '[caption id="attachment_1" align="alignleft" width="300"]<img src="x.jpg" /> Test caption[/caption]'
)

test_prepared_content <- prepare_wordpress_content(
  paste0(
    "Korte introductie.<!--more-->",
    '[caption id="attachment_1" align="alignleft" width="300"]',
    '<img src="x.jpg" /> Test caption',
    '[/caption]'
  )
)

test_prepared_batch <- prepare_wordpress_content(
  c(
    "Intro one.<!--more--><p>Body one.</p>",
    "<p>Whole body without marker.</p>",
    paste0(
      "Intro three.<!--more-->",
      '[caption id="attachment_1" align="alignright" width="300"]',
      '<img src="x.jpg" /> Caption',
      '[/caption]'
    ),
    ""
  )
)

test_wp_episode_text_source <- tibble(
  post_id = c(871100, 871101),
  locale = c("nl", "en"),
  translation_group_id = c(223729, 223729),
  original_post_id = c(NA_real_, NA_real_),
  post_content = c(
    paste0(
      "Nederlandse introductie.<!--more-->",
      '[caption id="attachment_875819" align="alignnone" width="300"]',
      '<img src="image.jpg" /> Michał Gondko en Corina Marti (La Morra)',
      '[/caption]'
    ),
    "This hour features a new, special CD with early music.<!--more-->"
  )
)

test_wp_episode_text_rows <- prepare_wp_episode_text_rows(
  test_wp_episode_text_source
)

test_realistic_episode_texts <- test_wp_episode_text_source |>
  prepare_wp_episode_text_rows() |>
  build_episode_texts()

test_wp_replay_episode_text <- tibble(
  post_id = 900119,
  locale = "nl",
  translation_group_id = 232571,
  original_post_id = 871100,
  post_content = "Replay text"
)

# expected to fail:
# prepare_wp_episode_text_rows(test_wp_replay_episode_text)
