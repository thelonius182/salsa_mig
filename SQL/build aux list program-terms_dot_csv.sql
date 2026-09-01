-- build aux list program-terms.csv
SELECT
    prog.term_id,
    prog.name AS source_title,
    prog.slug AS source_slug,
    prog_tt.parent AS parent_term_id,
    lang.slug AS language_slug,
    trans_tt.term_taxonomy_id AS translation_group_id
FROM wp_term_taxonomy AS prog_tt
JOIN wp_terms AS prog
    ON prog.term_id = prog_tt.term_id
JOIN wp_term_relationships AS lang_rel
    ON lang_rel.object_id = prog_tt.term_taxonomy_id
JOIN wp_term_taxonomy AS lang_tt
    ON lang_tt.term_taxonomy_id = lang_rel.term_taxonomy_id
JOIN wp_terms AS lang
    ON lang.term_id = lang_tt.term_id
JOIN wp_term_relationships AS trans_rel
    ON trans_rel.object_id = prog_tt.term_taxonomy_id
JOIN wp_term_taxonomy AS trans_tt
    ON trans_tt.term_taxonomy_id = trans_rel.term_taxonomy_id
WHERE prog_tt.taxonomy = 'programma_genre'
  AND prog_tt.parent <> 0
  AND lang_tt.taxonomy = 'term_language'
  AND trans_tt.taxonomy = 'term_translations'
ORDER BY prog.term_id;