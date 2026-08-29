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

