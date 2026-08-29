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

