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

