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

prepare_wp_post_text_rows <- function(wp_rows) {
  required_columns <- c("post_id",
                        "locale",
                        "translation_group_id",
                        "post_title",
                        "post_content")
  
  missing_columns <- setdiff(required_columns, names(wp_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required WordPress post text columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  if (any(is.na(wp_rows$post_id))) {
    stop("WordPress post is missing post_id")
  }
  
  if (any(is.na(wp_rows$locale) | wp_rows$locale == "")) {
    stop("WordPress post is missing locale")
  }
  
  prepared_content <- prepare_wordpress_content(wp_rows$post_content)
  
  wp_rows |>
    transmute(
      post_source_key = wp_post_source_key(translation_group_id, post_id),
      locale = as.character(locale),
      title = as.character(post_title)
    ) |>
    bind_cols(prepared_content)
}

prepare_wp_post_rows <- function(wp_rows) {
  required_columns <- c("post_id", "locale", "translation_group_id", "post_name")
  
  missing_columns <- setdiff(required_columns, names(wp_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required WordPress post columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  if (any(is.na(wp_rows$post_id))) {
    stop("WordPress post is missing post_id")
  }
  
  if (any(is.na(wp_rows$locale) | wp_rows$locale == "")) {
    stop("WordPress post is missing locale")
  }
  
  unexpected_locales <- wp_rows |>
    filter(!locale %in% c("nl", "en"))
  
  if (nrow(unexpected_locales) > 0) {
    stop("Unexpected WordPress post locale: ",
         paste(unique(unexpected_locales$locale), collapse = ", "))
  }
  
  prepared_rows <- wp_rows |>
    mutate(post_source_key = wp_post_source_key(translation_group_id, post_id))
  
  canonical_slugs <- prepared_rows |>
    arrange(post_source_key, factor(locale, levels = c("nl", "en"))) |>
    group_by(post_source_key) |>
    summarise(canonical_slug = first(post_name), .groups = "drop")
  
  prepared_rows |>
    transmute(
      post_source_key,
      locale = as.character(locale),
      wp_post_id = post_id,
      post_name = as.character(post_name)
    ) |>
    left_join(canonical_slugs, by = "post_source_key")
}

prepare_wp_term_rows <- function(wp_rows) {
  required_columns <- c("term_id", "locale", "translation_group_id", "slug", "name")
  
  missing_columns <- setdiff(required_columns, names(wp_rows))
  
  if (length(missing_columns) > 0) {
    stop("Missing required WordPress term columns: ",
         paste(missing_columns, collapse = ", "))
  }
  
  if (any(is.na(wp_rows$term_id))) {
    stop("WordPress term is missing term_id")
  }
  
  prepared_rows <- wp_rows |>
    mutate(
      locale = str_remove(as.character(locale), "^pll_"),
      term_source_key = wp_term_source_key(translation_group_id, term_id)
    )
  
  unexpected_locales <- prepared_rows |>
    filter(!locale %in% c("nl", "en"))
  
  if (nrow(unexpected_locales) > 0) {
    stop("Unexpected WordPress term locale: ",
         paste(unique(unexpected_locales$locale), collapse = ", "))
  }
  
  canonical_terms <- prepared_rows |>
    arrange(term_source_key, factor(locale, levels = c("nl", "en"))) |>
    group_by(term_source_key) |>
    summarise(
      canonical_slug = first(slug),
      canonical_name = first(name),
      .groups = "drop"
    )
  
  prepared_rows |>
    select(term_id, term_source_key, locale) |>
    left_join(canonical_terms, by = "term_source_key")
}

prepare_wp_category_rows <- function(wp_rows) {
  prepare_wp_term_rows(wp_rows) |>
    transmute(
      category_source_key = term_source_key,
      canonical_slug,
      canonical_name
    )
}

prepare_wp_tag_rows <- function(wp_rows) {
  prepare_wp_term_rows(wp_rows) |>
    transmute(
      tag_source_key = term_source_key,
      canonical_slug,
      canonical_name
    )
}

prepare_wp_post_term_rows <- function(wp_rows) {
  required_columns <- c(
    "post_id",
    "post_translation_group_id",
    "taxonomy",
    "term_id",
    "term_translation_group_id"
  )
  
  missing_columns <- setdiff(required_columns, names(wp_rows))
  
  if (length(missing_columns) > 0) {
    stop(
      "Missing required WordPress post-term columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
  
  if (any(is.na(wp_rows$post_id))) {
    stop("WordPress post-term relation is missing post_id")
  }
  
  if (any(is.na(wp_rows$term_id))) {
    stop("WordPress post-term relation is missing term_id")
  }
  
  unexpected_taxonomies <- wp_rows |>
    filter(!taxonomy %in% c("category", "post_tag"))
  
  if (nrow(unexpected_taxonomies) > 0) {
    stop("Unexpected WordPress post-term taxonomy: ",
         paste(unique(unexpected_taxonomies$taxonomy), collapse = ", "))
  }
  
  wp_rows |>
    transmute(
      post_source_key = wp_post_source_key(post_translation_group_id, post_id),
      taxonomy,
      term_source_key = wp_term_source_key(term_translation_group_id, term_id)
    ) |>
    distinct(post_source_key, taxonomy, term_source_key) |>
    arrange(post_source_key, taxonomy, term_source_key) |>
    group_by(post_source_key, taxonomy) |>
    mutate(position = row_number()) |>
    ungroup()
}

prepare_wp_post_category_rows <- function(wp_rows) {
  prepare_wp_post_term_rows(wp_rows) |>
    filter(taxonomy == "category") |>
    transmute(
      post_source_key,
      category_source_key = term_source_key,
      position
    )
}

prepare_wp_post_tag_rows <- function(wp_rows) {
  prepare_wp_post_term_rows(wp_rows) |>
    filter(taxonomy == "post_tag") |>
    transmute(
      post_source_key,
      tag_source_key = term_source_key,
      position
    )
}

wp_post_source_key <- function(translation_group_id, post_id) {
  if_else(
    !is.na(translation_group_id),
    as.character(translation_group_id),
    paste0("wp_post:", post_id)
  )
}

wp_term_source_key <- function(translation_group_id, term_id) {
  if_else(
    !is.na(translation_group_id),
    as.character(translation_group_id),
    paste0("wp_term:", term_id)
  )
}

