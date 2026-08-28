-- SET @from = '2026-08-20 00:00:00';
-- SET @to   = '2026-08-21 00:00:00';
SELECT
    b.post_id,
    b.locale,
    b.translation_group_id,

    b.starts_at,
    b.ends_at,
    TIMESTAMPDIFF(MINUTE, b.starts_at, b.ends_at) AS duration_minutes,

    b.title,
    b.description,

    b.stream_url,
    b.mood_raw,

    MAX(cpt.program_id) AS program_id,
    MAX(cp.title_nl) AS program_title_nl,
    MAX(cp.title_en) AS program_title_en,

    GROUP_CONCAT(
        DISTINCT cpt.genre_key
        ORDER BY cpt.genre_key
        SEPARATOR ','
    ) AS genre_keys,

    GROUP_CONCAT(
        DISTINCT g.title_nl
        ORDER BY cpt.genre_key
        SEPARATOR ','
    ) AS genre_titles_nl,

    GROUP_CONCAT(
        DISTINCT g.title_en
        ORDER BY cpt.genre_key
        SEPARATOR ','
    ) AS genre_titles_en,

    b.maker,
    b.maker_role,

    b.source_post_id

FROM (
    SELECT
        p.ID AS post_id,
        p.post_date AS starts_at,

        STR_TO_DATE(
            (
                SELECT pm.meta_value
                FROM wp_postmeta pm
                WHERE pm.post_id = p.ID
                  AND pm.meta_key = 'pr_metadata_uitzenddatum_end'
                LIMIT 1
            ),
            '%Y-%m-%d %H:%i'
        ) AS ends_at,

        COALESCE(
            NULLIF(
                CAST(
                    (
                        SELECT pm.meta_value
                        FROM wp_postmeta pm
                        WHERE pm.post_id = p.ID
                          AND pm.meta_key = 'pr_metadata_orig'
                        LIMIT 1
                    ) AS UNSIGNED
                ),
                0
            ),
            p.ID
        ) AS source_post_id,

        (
            SELECT t.slug
            FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt
                ON tt.term_taxonomy_id = tr.term_taxonomy_id
               AND tt.taxonomy = 'language'
            JOIN wp_terms t
                ON t.term_id = tt.term_id
            WHERE tr.object_id = p.ID
            LIMIT 1
        ) AS locale,

        (
            SELECT tt.term_id
            FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt
                ON tt.term_taxonomy_id = tr.term_taxonomy_id
               AND tt.taxonomy = 'post_translations'
            WHERE tr.object_id = p.ID
            LIMIT 1
        ) AS translation_group_id,

        COALESCE(
            NULLIF(TRIM(p.post_title), ''),
            NULLIF(TRIM(src.post_title), '')
        ) AS title,

        CASE
            WHEN NULLIF(
                TRIM(REPLACE(p.post_content, '<!--more-->', '')),
                ''
            ) IS NOT NULL
            THEN p.post_content
            ELSE src.post_content
        END AS description,

        (
            SELECT NULLIF(TRIM(pm.meta_value), '')
            FROM wp_postmeta pm
            WHERE pm.post_id = src.ID
              AND pm.meta_key = 'pr_metadata_stream'
            LIMIT 1
        ) AS stream_url,
        
        (
            SELECT NULLIF(TRIM(pm.meta_value), '')
            FROM wp_postmeta pm
            WHERE pm.post_id = p.ID
              AND pm.meta_key = 'pr_mood_file'
            LIMIT 1
        ) AS mood_raw,

        (
            SELECT t.name
            FROM wp_term_relationships tr
            JOIN wp_term_taxonomy tt
                ON tt.term_taxonomy_id = tr.term_taxonomy_id
               AND tt.taxonomy = 'programma_maker'
            JOIN wp_terms t
                ON t.term_id = tt.term_id
            WHERE tr.object_id = src.ID
            LIMIT 1
        ) AS maker,

        (
            SELECT NULLIF(TRIM(pm.meta_value), '')
            FROM wp_postmeta pm
            WHERE pm.post_id = src.ID
              AND pm.meta_key = 'pr_metadata_production1_taak'
            LIMIT 1
        ) AS maker_role

    FROM wp_posts p

    LEFT JOIN wp_posts src
        ON src.ID = COALESCE(
            NULLIF(
                CAST(
                    (
                        SELECT pm.meta_value
                        FROM wp_postmeta pm
                        WHERE pm.post_id = p.ID
                          AND pm.meta_key = 'pr_metadata_orig'
                        LIMIT 1
                    ) AS UNSIGNED
                ),
                0
            ),
            p.ID
        )

    WHERE p.post_type = 'programma'
      AND p.post_status = 'publish'
      AND p.post_date >= @from
      AND p.post_date <  @to
) AS b

JOIN wp_term_relationships tr
    ON tr.object_id = b.source_post_id

JOIN wp_term_taxonomy tt
    ON tt.term_taxonomy_id = tr.term_taxonomy_id
   AND tt.taxonomy = 'programma_genre'

JOIN cpnm_compat_program_terms cpt
    ON cpt.term_id = tt.term_id

JOIN cpnm_compat_programs cp
    ON cp.program_id = cpt.program_id

JOIN cpnm_compat_genres g
    ON g.genre_key = cpt.genre_key

GROUP BY
    b.post_id,
    b.locale,
    b.translation_group_id,
    b.starts_at,
    b.ends_at,
    b.title,
    b.description,
    b.stream_url,
    b.mood_raw,
    b.maker,
    b.maker_role,
    b.source_post_id

ORDER BY
    b.starts_at,
    b.post_id;