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

