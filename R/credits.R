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

