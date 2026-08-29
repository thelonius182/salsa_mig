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

