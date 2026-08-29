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

test_wp_program_terms <- tibble(
  term_id = c(
    # Concertzender Live: multiple genre aliases
    17016, 17018, 17256, 23885,
    
    # Nuove Musiche: NL/EN not paired by Polylang
    27889, 27891,
    
    # Franz Liszt: canonical historical terms are out of scope
    39184, 41697, 43090, 44827
  ),
  source_title = c(
    "Concertzender Live",
    "Concertzender Live",
    "Concertzender Live",
    "Concertzender Live",
    
    "Nuove Musiche",
    "Nuove Musiche",
    
    "Franz Liszt, episodes uit het leven van een artiest",
    "Franz Liszt, episodes from the life of an artist",
    "Franz Liszt, episodes uit het leven van een artiest",
    "Franz Liszt, episodes from the life of an artist"
  ),
  source_slug = c(
    "concertzender-live__jazz-nl",
    "concertzender-live__jazz-en",
    "concertzender-live__oud-nl",
    "concertzender-live__oud-en",
    
    "nuove-musiche__oud-nl",
    "nuove-musiche__oud-en",
    
    "franz-liszt-episodes-uit-het-leven-van-een-artiest__raakvlakken-nl",
    "franz-liszt-episodes-uit-het-leven-van-een-artiest__raakvlakken-en",
    "franz-liszt-episodes-uit-het-leven-van-een-artiest__klassiek-nl",
    "franz-liszt-episodes-uit-het-leven-van-een-artiest__klassiek-en"
  ),
  parent_term_id = c(
    16766, 16768, 3048, 3050,
    3048, 3050,
    17242, 17244, 3266, 3268
  ),
  language_slug = c(
    "pll_nl", "pll_en", "pll_nl", "pll_en",
    "pll_nl", "pll_en",
    "pll_nl", "pll_en", "pll_nl", "pll_en"
  )
)

test_wp_programs <- build_programs(
  test_wp_program_compat$compat_programs,
  test_wp_program_compat$compat_program_terms
)

test_wp_program_term_map <- build_program_term_map(
  test_wp_program_compat$compat_program_terms
)

stopifnot(
  nrow(test_wp_program_compat$compat_programs) == 3L,
  
  # Canonical program identities.
  17016 %in% test_wp_program_compat$compat_programs$program_id,
  27889 %in% test_wp_program_compat$compat_programs$program_id,
  39184 %in% test_wp_program_compat$compat_programs$program_id,
  
  # Canonical logical slugs.
  test_wp_programs |>
    filter(source_id == "17016") |>
    pull(slug) |>
    identical("concertzender-live"),
  
  test_wp_programs |>
    filter(source_id == "27889") |>
    pull(slug) |>
    identical("nuove-musiche"),
  
  test_wp_programs |>
    filter(source_id == "39184") |>
    pull(slug) |>
    identical(
      "franz-liszt-episodes-uit-het-leven-van-een-artiest"
    ),
  
  # Later in-scope Franz Liszt aliases retain the historical
  # canonical program identity.
  test_wp_program_term_map |>
    filter(term_id == "43090") |>
    pull(source_program_id) |>
    identical("39184"),
  
  test_wp_program_term_map |>
    filter(term_id == "44827") |>
    pull(source_program_id) |>
    identical("39184"),
  
  # Broken Polylang pairing does not split Nuove Musiche.
  test_wp_program_term_map |>
    filter(term_id == "27891") |>
    pull(source_program_id) |>
    identical("27889")
)

test_wp_in_scope_program_terms <- tibble(
  term_id = c(
    17016,
    17018,
    27889,
    27891,
    
    # Only the later Franz Liszt aliases are in scope.
    43090,
    44827
  )
)

test_wp_program_compat <- prepare_wp_program_compat(
  historical_program_terms = test_wp_program_terms,
  in_scope_program_terms = test_wp_in_scope_program_terms
)

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

# test_categories ----
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

# test_post_categories
test_post_category_rows <- tibble(
  post_source_key = c(48123, 48123, 48123),
  category_source_key = c(12, 12, 27),
  position = c(1, 1, 2)
)

test_post_categories <- build_post_categories(
  test_post_category_rows,
  test_category_rows
)

# test_post_tags ----
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

# test_wp_episode_text_rows ----
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

# test_realistic_episode_texts ----
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

# test_wp_post_text_rows ----
test_wp_post_text_source <- tibble(
  post_id = c(905199, 905419, 920001),
  locale = c("nl", "en", "nl"),
  translation_group_id = c(234245, 234245, NA),
  post_title = c(
    "In Memoriam: bas Harry van der Kamp (1947-2026)",
    "In Memoriam : bass Harry van der Kamp ( 1947 - 2026 )",
    "Nederlandse standalone test"
  ),
  post_content = c(
    paste0(
      "In Documento van donderdag 3 september zenden we een In Memoriam uit.",
      "<!--more-->",
      "<p>Harry van der Kamp studeerde eerst rechten en psychologie.</p>"
    ),
    paste0(
      "<p>In Documento on Thursday, September 3rd, we will broadcast an In Memoriam.</p>",
      "<p>Harry van der Kamp initially studied law and psychology.</p>"
    ),
    "Korte introductie.<!--more--><p>Standalone inhoud.</p>"
  )
)

test_wp_post_text_rows <- prepare_wp_post_text_rows(
  test_wp_post_text_source
)

test_realistic_post_texts <- test_wp_post_text_source |>
  prepare_wp_post_text_rows() |>
  build_post_texts()

# test_wp_post_rows ----
test_wp_post_source <- tibble(
  post_id = c(905199, 905419, 910001, 920001),
  locale = c("nl", "en", "en", "nl"),
  translation_group_id = c(234245, 234245, NA, NA),
  post_name = c(
    "in-memoriam-bas-harry-van-der-kamp-1947-2026",
    "in-memoriam-bass-harry-van-der-kamp-1947-2026",
    "english-only-standalone",
    "nederlands-los-bericht"
  )
)

test_wp_post_rows <- prepare_wp_post_rows(
  test_wp_post_source
)

# test_realistic_posts ----
test_realistic_posts <- test_wp_post_source |>
  prepare_wp_post_rows() |>
  build_posts()

# test_wp_post_text_rows ----
test_wp_post_text_rows <- prepare_wp_post_text_rows(
  test_wp_post_text_source
)

# test_wp_term_rows ----
test_wp_term_source <- tibble(
  term_id = c(26, 34, 567),
  locale = c("pll_nl", "pll_en", "pll_en"),
  translation_group_id = c(472, 472, NA),
  slug = c(
    "blogs",
    "blogs-en",
    "voorpagina-en"
  ),
  name = c(
    "Blogs",
    "Blogs",
    "Voorpagina"
  )
)

# test_categories_realistic ----
test_wp_term_rows <- prepare_wp_term_rows(
  test_wp_term_source
)

test_wp_category_rows <- prepare_wp_category_rows(
  test_wp_term_source
)

test_categories_realistic <- build_categories(
  test_wp_category_rows
)

# test_tags_realistic ----
test_wp_tag_rows <- prepare_wp_tag_rows(
  test_wp_term_source
)

test_tags_realistic <- build_tags(
  test_wp_tag_rows
)

# wp_category_rows <- wpt |>
#   filter(taxonomy == "category") |>
#   prepare_wp_category_rows()
# 
# wp_tag_rows <- wpt |>
#   filter(taxonomy == "post_tag") |>
#   prepare_wp_tag_rows()
# 
# real_categories <- build_categories(wp_category_rows)
# real_tags <- build_tags(wp_tag_rows)

# test_wp_post_term_rows ----
test_wp_post_term_source <- tibble(
  post_id = c(
    905199, 905419,
    905199, 905419,
    920001
  ),
  post_translation_group_id = c(
    234245, 234245,
    234245, 234245,
    NA
  ),
  taxonomy = c(
    "category", "category",
    "category", "category",
    "post_tag"
  ),
  term_id = c(
    26, 34,
    20, 42,
    840
  ),
  term_translation_group_id = c(
    472, 472,
    480, 480,
    NA
  )
)

# test_post_categories_realistic ----
test_wp_category_source <- tibble(
  term_id = c(26, 34, 20, 42),
  locale = c("pll_nl", "pll_en", "pll_nl", "pll_en"),
  translation_group_id = c(472, 472, 480, 480),
  slug = c(
    "blogs",
    "blogs-en",
    "voorpagina",
    "front-page"
  ),
  name = c(
    "Blogs",
    "Blogs",
    "Voorpagina",
    "Front Page"
  )
)

test_wp_category_rows <- prepare_wp_category_rows(
  test_wp_category_source
)

test_wp_post_category_rows <- prepare_wp_post_category_rows(
  test_wp_post_term_source
)

test_post_categories_realistic <- build_post_categories(
  test_wp_post_category_rows,
  test_wp_category_rows
)

# test_post_tags_realistic ----
test_wp_tag_source <- tibble(
  term_id = c(840),
  locale = c("pll_nl"),
  translation_group_id = c(NA),
  slug = c("gonzocircusmag"),
  name = c("@gonzocircusmag")
)

test_wp_tag_rows <- prepare_wp_tag_rows(
  test_wp_tag_source
)

test_wp_post_tag_rows <- prepare_wp_post_tag_rows(
  test_wp_post_term_source
)

test_post_tags_realistic <- build_post_tags(
  test_wp_post_tag_rows,
  test_wp_tag_rows
)

real_wp_post_term_rows <- prepare_wp_post_term_rows(wptr)

real_wp_post_term_rows |>
  count(taxonomy, name = "logical_relation_count")

real_wp_post_category_rows <- prepare_wp_post_category_rows(wptr)

real_wp_post_tag_rows <- prepare_wp_post_tag_rows(wptr)

wp_category_rows <- wpt |>
  filter(taxonomy == "category") |>
  prepare_wp_category_rows()

wp_tag_rows <- wpt |>
  filter(taxonomy == "post_tag") |>
  prepare_wp_tag_rows()

real_post_categories <- build_post_categories(
  real_wp_post_category_rows,
  wp_category_rows
)

real_post_tags <- build_post_tags(
  real_wp_post_tag_rows,
  wp_tag_rows
)

nrow(real_post_categories)
nrow(real_post_tags)
