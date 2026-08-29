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

