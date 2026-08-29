pacman::p_load(readr, igraph)

wpt <- read_csv(file = "/mnt/muw/wp_terms_export.csv", show_col_types = FALSE)

wpt <- wpt |>
  mutate(
    translation_group_id = na_if(
      translation_group_id,
      "NULL"
    )
  )
wpt |>
  summarise(
    rows = n(),
    missing_translation_group = sum(is.na(translation_group_id))
  )

wptr <- read_csv(file = "/mnt/muw/wp_post_term_relations.csv", show_col_types = FALSE)

wptr <- wptr |>
  mutate(
    post_translation_group_id = na_if(
      post_translation_group_id,
      "NULL"
    ),
    term_translation_group_id = na_if(
      term_translation_group_id,
      "NULL"
    )
  )

pgm_trms <- read_csv(file = "/mnt/muw/programs-terms.csv", show_col_types = FALSE)

# pgm_trms |>
#   mutate(
#     is_top_level = parent_term_id == 0,
#     has_double_underscore = str_detect(source_slug, "__")
#   ) |>
#   count(is_top_level, has_double_underscore)
# 
# pgm_trms |>
#   left_join(
#     pgm_trms |>
#       count(parent_term_id, name = "child_count") |>
#       rename(term_id = parent_term_id),
#     by = "term_id"
#   ) |>
#   mutate(
#     child_count = coalesce(child_count, 0L),
#     is_top_level = parent_term_id == 0,
#     has_double_underscore = str_detect(source_slug, "__"),
#     has_children = child_count > 0
#   ) |>
#   count(
#     is_top_level,
#     has_double_underscore,
#     has_children
#   )
# 
# pgm_trms |>
#   filter(
#     parent_term_id != 0,
#     !str_detect(source_slug, "__")
#   ) |>
#   select(
#     term_id,
#     source_title,
#     source_slug,
#     parent_term_id,
#     language_slug
#   ) |>
#   slice_head(n = 30) |> print(n=30)
# 
# pgm_trms |>
#   filter(parent_term_id == 0) |>
#   left_join(
#     pgm_trms |>
#       count(parent_term_id, name = "child_count") |>
#       rename(term_id = parent_term_id),
#     by = "term_id"
#   ) |>
#   mutate(child_count = coalesce(child_count, 0L)) |>
#   filter(child_count == 0) |>
#   select(
#     term_id,
#     source_title,
#     source_slug,
#     language_slug
#   )

program_terms <- pgm_trms |>
  filter(parent_term_id != 0)

# program_terms |>
#   count(language_slug)
# 
# pgm_trms |>
#   mutate(
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     )
#   ) |>
#   group_by(translation_group_id) |>
#   summarise(
#     term_count = n(),
#     nl_count = sum(locale == "nl"),
#     en_count = sum(locale == "en"),
#     .groups = "drop"
#   ) |>
#   summarise(
#     translation_groups = n(),
#     nl_en_groups = sum(nl_count == 1 & en_count == 1),
#     nl_only_groups = sum(nl_count == 1 & en_count == 0),
#     en_only_groups = sum(nl_count == 0 & en_count == 1),
#     duplicate_locale_groups = sum(nl_count > 1 | en_count > 1),
#     groups_over_two_terms = sum(term_count > 2)
#   )

program_singletons <- pgm_trms |>
  add_count(translation_group_id, name = "group_size") |>
  filter(group_size == 1) |>
  mutate(
    locale = case_match(
      language_slug,
      "pll_nl" ~ "nl",
      "pll_en" ~ "en",
      .default = NA_character_
    )
  )

# program_singletons |>
#   count(source_title, locale) |>
#   pivot_wider(
#     names_from = locale,
#     values_from = n,
#     values_fill = 0
#   ) |>
#   summarise(
#     distinct_titles = n(),
#     titles_in_both_locales = sum(nl > 0 & en > 0),
#     unique_one_to_one_titles = sum(nl == 1 & en == 1),
#     ambiguous_titles = sum(nl > 1 | en > 1)
#   )
# ----------------
program_singletons <- pgm_trms |>
  add_count(translation_group_id, name = "group_size") |>
  filter(group_size == 1) |>
  mutate(
    locale = case_match(
      language_slug,
      "pll_nl" ~ "nl",
      "pll_en" ~ "en",
      .default = NA_character_
    )
  )

# program_singletons |>
#   count(source_title, locale) |>
#   pivot_wider(
#     names_from = locale,
#     values_from = n,
#     values_fill = 0
#   ) |>
#   summarise(
#     distinct_titles = n(),
#     titles_in_both_locales = sum(nl > 0 & en > 0),
#     unique_one_to_one_titles = sum(nl == 1 & en == 1),
#     ambiguous_titles = sum(nl > 1 | en > 1)
#   )

# pgm_trms |>
#   filter(source_title %in% c(
#     "Concertzender Live",
#     "Nuove Musiche"
#   )) |>
#   arrange(source_title, language_slug, term_id) |>
#   select(
#     term_id,
#     source_title,
#     source_slug,
#     parent_term_id,
#     language_slug,
#     translation_group_id
#   )

in_scope_program_terms <- read_csv("/mnt/muw/in_scope_program_terms.csv", show_col_types = FALSE)
# in_scope_program_terms |>
#   mutate(
#     slug_stem = str_remove(source_slug, "__.*$")
#   ) |>
#   summarise(
#     program_terms = n(),
#     distinct_titles = n_distinct(source_title),
#     distinct_slug_stems = n_distinct(slug_stem)
#   )
# 
# in_scope_program_terms |>
#   left_join(
#     pgm_trms |>
#       select(term_id, language_slug),
#     by = "term_id"
#   ) |>
#   mutate(
#     slug_stem = str_remove(source_slug, "__.*$"),
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     )
#   ) |>
#   group_by(slug_stem, locale) |>
#   summarise(
#     term_count = n(),
#     title_count = n_distinct(source_title),
#     .groups = "drop"
#   ) |>
#   summarise(
#     stem_locale_groups = n(),
#     groups_with_multiple_terms = sum(term_count > 1),
#     groups_with_multiple_titles = sum(title_count > 1),
#     max_titles_per_stem_locale = max(title_count)
#   )
# 
# in_scope_program_terms |>
#   left_join(
#     pgm_trms |>
#       select(term_id, language_slug),
#     by = "term_id"
#   ) |>
#   mutate(
#     slug_stem = str_remove(source_slug, "__.*$"),
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     )
#   ) |>
#   group_by(slug_stem) |>
#   summarise(
#     nl_min_term_id = min(term_id[locale == "nl"], na.rm = TRUE),
#     en_min_term_id = min(term_id[locale == "en"], na.rm = TRUE),
#     .groups = "drop"
#   ) |>
#   filter(slug_stem %in% c(
#     "concertzender-live",
#     "nuove-musiche"
#   ))
# 
# pgm_trms |>
#   mutate(
#     slug_stem = str_remove(source_slug, "__.*$"),
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     )
#   ) |>
#   group_by(slug_stem, locale) |>
#   summarise(
#     term_count = n(),
#     title_count = n_distinct(source_title),
#     .groups = "drop"
#   ) |>
#   summarise(
#     stem_locale_groups = n(),
#     groups_with_multiple_terms = sum(term_count > 1),
#     groups_with_multiple_titles = sum(title_count > 1),
#     max_titles_per_stem_locale = max(title_count)
#   )

program_identity_candidates <- pgm_trms |>
  mutate(
    slug_stem = str_remove(source_slug, "__.*$"),
    locale = case_match(
      language_slug,
      "pll_nl" ~ "nl",
      "pll_en" ~ "en",
      .default = NA_character_
    )
  ) |>
  group_by(slug_stem) |>
  summarise(
    nl_min_term_id = if (any(locale == "nl")) {
      min(term_id[locale == "nl"])
    } else {
      NA_real_
    },
    en_min_term_id = if (any(locale == "en")) {
      min(term_id[locale == "en"])
    } else {
      NA_real_
    },
    .groups = "drop"
  ) |>
  mutate(
    program_id = coalesce(nl_min_term_id, en_min_term_id)
  )

# program_identity_candidates |>
#   summarise(
#     logical_programs = n(),
#     with_nl = sum(!is.na(nl_min_term_id)),
#     with_en = sum(!is.na(en_min_term_id)),
#     nl_en = sum(!is.na(nl_min_term_id) & !is.na(en_min_term_id)),
#     nl_only = sum(!is.na(nl_min_term_id) & is.na(en_min_term_id)),
#     en_only = sum(is.na(nl_min_term_id) & !is.na(en_min_term_id))
#   )

in_scope_program_identities <- in_scope_program_terms |>
  mutate(
    slug_stem = str_remove(source_slug, "__.*$")
  ) |>
  distinct(slug_stem) |>
  inner_join(
    program_identity_candidates,
    by = "slug_stem"
  ) |>
  mutate(
    canonical_term_in_scope =
      program_id %in% in_scope_program_terms$term_id
  )

# in_scope_program_identities |>
#   summarise(
#     in_scope_programs = n(),
#     canonical_term_in_scope = sum(canonical_term_in_scope),
#     canonical_term_outside_scope = sum(!canonical_term_in_scope)
#   )
# 
# in_scope_program_identities |>
#   count(canonical_term_in_scope, .drop = FALSE)
# 
# in_scope_program_identities |>
#   filter(
#     is.na(canonical_term_in_scope) |
#       !canonical_term_in_scope
#   ) |>
#   select(
#     slug_stem,
#     nl_min_term_id,
#     en_min_term_id,
#     program_id,
#     canonical_term_in_scope
#   )
# 
# pgm_trms |>
#   mutate(
#     slug_stem = str_remove(source_slug, "__.*$")
#   ) |>
#   filter(
#     slug_stem ==
#       "franz-liszt-episodes-uit-het-leven-van-een-artiest"
#   ) |>
#   mutate(
#     in_scope = term_id %in% in_scope_program_terms$term_id
#   ) |>
#   arrange(language_slug, term_id) |>
#   select(
#     term_id,
#     source_title,
#     source_slug,
#     parent_term_id,
#     language_slug,
#     translation_group_id,
#     in_scope
#   )
# 
# program_identity_candidates |>
#   filter(
#     !is.na(nl_min_term_id),
#     !is.na(en_min_term_id)
#   ) |>
#   summarise(
#     bilingual_programs = n(),
#     nl_term_is_older = sum(nl_min_term_id < en_min_term_id),
#     en_term_is_older = sum(en_min_term_id < nl_min_term_id)
#   )
# 
# program_identity_candidates |>
#   filter(
#     !is.na(nl_min_term_id),
#     !is.na(en_min_term_id),
#     en_min_term_id < nl_min_term_id
#   ) |>
#   left_join(
#     pgm_trms |>
#       select(
#         nl_min_term_id = term_id,
#         nl_title = source_title,
#         nl_slug = source_slug
#       ),
#     by = "nl_min_term_id"
#   ) |>
#   left_join(
#     pgm_trms |>
#       select(
#         en_min_term_id = term_id,
#         en_title = source_title,
#         en_slug = source_slug
#       ),
#     by = "en_min_term_id"
#   ) |>
#   select(
#     slug_stem,
#     nl_min_term_id,
#     nl_title,
#     nl_slug,
#     en_min_term_id,
#     en_title,
#     en_slug
#   )
# 
# pgm_trms |>
#   mutate(
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     ),
#     slug_stem = str_remove(source_slug, "__.*$")
#   ) |>
#   group_by(locale, source_title) |>
#   summarise(
#     term_count = n(),
#     stem_count = n_distinct(slug_stem),
#     .groups = "drop"
#   ) |>
#   summarise(
#     localized_titles = n(),
#     titles_with_multiple_terms = sum(term_count > 1),
#     titles_with_multiple_stems = sum(stem_count > 1),
#     max_stems_per_title = max(stem_count)
#   )
# 
# pgm_trms |>
#   mutate(
#     locale = case_match(
#       language_slug,
#       "pll_nl" ~ "nl",
#       "pll_en" ~ "en",
#       .default = NA_character_
#     ),
#     slug_stem = str_remove(source_slug, "__.*$")
#   ) |>
#   group_by(locale, source_title) |>
#   filter(n_distinct(slug_stem) > 1) |>
#   summarise(
#     term_ids = str_c(sort(term_id), collapse = ", "),
#     slug_stems = str_c(
#       sort(unique(slug_stem)),
#       collapse = " | "
#     ),
#     .groups = "drop"
#   ) |>
#   arrange(locale, source_title) |> print(n=37)
