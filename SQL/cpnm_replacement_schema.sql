-- CPNM replacement: explicit MariaDB domain schema + API resource SELECTs
-- Target: MariaDB 10.11+ (LTS; JSON_ARRAYAGG / JSON_OBJECTAGG)
-- Convention: all DATETIME(6) values are stored in UTC.
-- IDs remain CHAR(36) UUID strings to simplify migration from the existing database.

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Reusable assets
-- -----------------------------------------------------------------------------

CREATE TABLE images (
    id          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    url         VARCHAR(2048) NOT NULL,
    alt_text    VARCHAR(500) NULL,
    mime_type   VARCHAR(100) NULL,
    width_px    INT UNSIGNED NULL,
    height_px   INT UNSIGNED NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audio_files (
    id               CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    url              VARCHAR(2048) NOT NULL,
    file_name        VARCHAR(255) NULL,
    mime_type        VARCHAR(100) NULL,
    duration_seconds DECIMAL(12,3) NULL,
    PRIMARY KEY (id),
    CONSTRAINT chk_audio_duration
        CHECK (duration_seconds IS NULL OR duration_seconds >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE artists (
    id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name    VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_artists_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE editors (
    id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name    VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    KEY idx_editors_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Programs / genres
-- -----------------------------------------------------------------------------

CREATE TABLE programs (
    id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slug    VARCHAR(190) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_programs_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE program_texts (
    program_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    locale       VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title        VARCHAR(255) NOT NULL,
    description  TEXT NULL,
    PRIMARY KEY (program_id, locale),
    CONSTRAINT fk_program_texts_program
        FOREIGN KEY (program_id) REFERENCES programs(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE genres (
    id    SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    slug  VARCHAR(100) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_genres_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE genre_texts (
    genre_id  SMALLINT UNSIGNED NOT NULL,
    locale    VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name      VARCHAR(100) NOT NULL,
    PRIMARY KEY (genre_id, locale),
    CONSTRAINT fk_genre_texts_genre
        FOREIGN KEY (genre_id) REFERENCES genres(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  
CREATE TABLE program_genres (
    program_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    genre_id    SMALLINT UNSIGNED NOT NULL,
    position    TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (program_id, genre_id),
    UNIQUE KEY uq_program_genres_position (program_id, position),
    KEY idx_program_genres_genre (genre_id),
    CONSTRAINT chk_program_genres_position CHECK (position >= 1),
    CONSTRAINT fk_program_genres_program
        FOREIGN KEY (program_id) REFERENCES programs(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_program_genres_genre
        FOREIGN KEY (genre_id) REFERENCES genres(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subgenres (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    genre_id  SMALLINT UNSIGNED NOT NULL,
    slug      VARCHAR(190) NOT NULL,
    name      VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_subgenres_genre_slug (genre_id, slug),
    KEY idx_subgenres_name (name),
    CONSTRAINT fk_subgenres_genre
        FOREIGN KEY (genre_id) REFERENCES genres(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Episodes
-- -----------------------------------------------------------------------------

CREATE TABLE episodes (
    id              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    program_id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slug            VARCHAR(190) NOT NULL,
    image_id        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    audio_id        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    mood_wave       TINYINT UNSIGNED NULL,
    mood_color      TINYINT UNSIGNED NULL,
    mood_tempo      TINYINT UNSIGNED NULL,
    mood_intensity  TINYINT UNSIGNED NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_episodes_program_slug (program_id, slug),
    KEY idx_episodes_program (program_id),
    KEY idx_episodes_image (image_id),
    KEY idx_episodes_audio (audio_id),
    CONSTRAINT fk_episodes_program
        FOREIGN KEY (program_id) REFERENCES programs(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_episodes_image
        FOREIGN KEY (image_id) REFERENCES images(id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_episodes_audio
        FOREIGN KEY (audio_id) REFERENCES audio_files(id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE episode_texts (
    episode_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    locale       VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    subtitle     VARCHAR(255) NULL,
    description  TEXT NULL,
    content      JSON NULL,
    PRIMARY KEY (episode_id, locale),
    CONSTRAINT fk_episode_texts_episode
        FOREIGN KEY (episode_id) REFERENCES episodes(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE episode_subgenres (
    episode_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    subgenre_id  INT UNSIGNED NOT NULL,
    position     SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (episode_id, subgenre_id),
    UNIQUE KEY uq_episode_subgenres_position (episode_id, position),
    KEY idx_episode_subgenres_subgenre (subgenre_id),
    CONSTRAINT chk_episode_subgenres_position CHECK (position >= 1),
    CONSTRAINT fk_episode_subgenres_episode
        FOREIGN KEY (episode_id) REFERENCES episodes(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_episode_subgenres_subgenre
        FOREIGN KEY (subgenre_id) REFERENCES subgenres(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE episode_artists (
    episode_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    artist_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    position    SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (episode_id, artist_id),
    UNIQUE KEY uq_episode_artists_position (episode_id, position),
    KEY idx_episode_artists_artist (artist_id),
    CONSTRAINT chk_episode_artists_position CHECK (position >= 1),
    CONSTRAINT fk_episode_artists_episode
        FOREIGN KEY (episode_id) REFERENCES episodes(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_episode_artists_artist
        FOREIGN KEY (artist_id) REFERENCES artists(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE episode_editors (
    episode_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    editor_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role        ENUM('producer', 'producer_presenter', 'unspecified') NOT NULL,
    position    SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (episode_id, editor_id),
    UNIQUE KEY uq_episode_editors_position (episode_id, position),
    KEY idx_episode_editors_editor (editor_id),
    CONSTRAINT chk_episode_editors_position CHECK (position >= 1),
    CONSTRAINT fk_episode_editors_episode
        FOREIGN KEY (episode_id) REFERENCES episodes(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_episode_editors_editor
        FOREIGN KEY (editor_id) REFERENCES editors(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Broadcasts: deliberately minimal
-- -----------------------------------------------------------------------------

CREATE TABLE broadcasts (
    id          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    episode_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    starts_at   DATETIME(6) NOT NULL,
    ends_at     DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_broadcast_episode_start (episode_id, starts_at),
    KEY idx_broadcast_starts_at (starts_at),
    KEY idx_broadcast_episode_time (episode_id, starts_at DESC),
    CONSTRAINT chk_broadcast_time CHECK (ends_at > starts_at),
    CONSTRAINT fk_broadcast_episode
        FOREIGN KEY (episode_id) REFERENCES episodes(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Cross-table business rule:
-- an episode can only use subgenres belonging to one of its program's genres.
-- -----------------------------------------------------------------------------

DELIMITER //

CREATE TRIGGER trg_episode_subgenres_bi
BEFORE INSERT ON episode_subgenres
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM episodes e
        JOIN subgenres sg
          ON sg.id = NEW.subgenre_id
        JOIN program_genres pg
          ON pg.program_id = e.program_id
         AND pg.genre_id = sg.genre_id
        WHERE e.id = NEW.episode_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Episode subgenre must belong to one of the program genres';
    END IF;
END//

CREATE TRIGGER trg_episode_subgenres_bu
BEFORE UPDATE ON episode_subgenres
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM episodes e
        JOIN subgenres sg
          ON sg.id = NEW.subgenre_id
        JOIN program_genres pg
          ON pg.program_id = e.program_id
         AND pg.genre_id = sg.genre_id
        WHERE e.id = NEW.episode_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Episode subgenre must belong to one of the program genres';
    END IF;
END//

CREATE TRIGGER trg_program_genres_bd
BEFORE DELETE ON program_genres
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM episodes e
        JOIN episode_subgenres es
          ON es.episode_id = e.id
        JOIN subgenres sg
          ON sg.id = es.subgenre_id
        WHERE e.program_id = OLD.program_id
          AND sg.genre_id = OLD.genre_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot remove a program genre while episodes use one of its subgenres';
    END IF;
END//

CREATE TRIGGER trg_program_genres_bu
BEFORE UPDATE ON program_genres
FOR EACH ROW
BEGIN
    IF (NEW.program_id <> OLD.program_id OR NEW.genre_id <> OLD.genre_id)
       AND EXISTS (
            SELECT 1
            FROM episodes e
            JOIN episode_subgenres es
              ON es.episode_id = e.id
            JOIN subgenres sg
              ON sg.id = es.subgenre_id
            WHERE e.program_id = OLD.program_id
              AND sg.genre_id = OLD.genre_id
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot change a program genre while episodes use one of its subgenres';
    END IF;
END//

CREATE TRIGGER trg_subgenres_bu
BEFORE UPDATE ON subgenres
FOR EACH ROW
BEGIN
    IF NEW.genre_id <> OLD.genre_id
       AND EXISTS (
            SELECT 1
            FROM episode_subgenres es
            JOIN episodes e
              ON e.id = es.episode_id
            LEFT JOIN program_genres pg
              ON pg.program_id = e.program_id
             AND pg.genre_id = NEW.genre_id
            WHERE es.subgenre_id = OLD.id
              AND pg.program_id IS NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot move subgenre to a genre not used by all linked episode programs';
    END IF;
END//

CREATE TRIGGER trg_episodes_bu
BEFORE UPDATE ON episodes
FOR EACH ROW
BEGIN
    IF NEW.program_id <> OLD.program_id
       AND EXISTS (
            SELECT 1
            FROM episode_subgenres es
            JOIN subgenres sg
              ON sg.id = es.subgenre_id
            LEFT JOIN program_genres pg
              ON pg.program_id = NEW.program_id
             AND pg.genre_id = sg.genre_id
            WHERE es.episode_id = OLD.id
              AND pg.program_id IS NULL
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot move episode to a program incompatible with its subgenres';
    END IF;
END//

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Posts/articles: categories and tags belong here, not to radio resources.
-- The text/content shell is intentionally simple because post ownership beyond
-- categories/tags was not part of the settled redesign decisions.
-- -----------------------------------------------------------------------------

CREATE TABLE posts (
    id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slug    VARCHAR(190) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_posts_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE post_texts (
    post_id       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    locale        VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title         VARCHAR(255) NOT NULL,
    description   TEXT NULL,
    content       JSON NULL,
    PRIMARY KEY (post_id, locale),
    CONSTRAINT fk_post_texts_post
        FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categories (
    id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    slug    VARCHAR(190) NOT NULL,
    name    VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tags (
    id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    slug    VARCHAR(190) NOT NULL,
    name    VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_tags_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE post_categories (
    post_id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    category_id  INT UNSIGNED NOT NULL,
    position     SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (post_id, category_id),
    UNIQUE KEY uq_post_categories_position (post_id, position),
    KEY idx_post_categories_category (category_id),
    CONSTRAINT fk_post_categories_post
        FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_post_categories_category
        FOREIGN KEY (category_id) REFERENCES categories(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE post_tags (
    post_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tag_id    INT UNSIGNED NOT NULL,
    position  SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (post_id, tag_id),
    UNIQUE KEY uq_post_tags_position (post_id, position),
    KEY idx_post_tags_tag (tag_id),
    CONSTRAINT fk_post_tags_post
        FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_post_tags_tag
        FOREIGN KEY (tag_id) REFERENCES tags(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ConcertPodium / recording collections
-- Settled only to collection -> recorded concerts -> venue, plus reusable artists.
-- Tracks/segments are intentionally omitted until their ownership is established.
-- -----------------------------------------------------------------------------

CREATE TABLE venues (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name          VARCHAR(255) NOT NULL,
    city          VARCHAR(255) NULL,
    address       VARCHAR(500) NULL,
    country_code  CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NULL,
    PRIMARY KEY (id),
    KEY idx_venues_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recording_collections (
    id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slug    VARCHAR(190) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_recording_collections_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recording_collection_texts (
    recording_collection_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    locale                    VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    title                     VARCHAR(255) NOT NULL,
    description               TEXT NULL,
    PRIMARY KEY (recording_collection_id, locale),
    CONSTRAINT fk_recording_collection_texts_collection
        FOREIGN KEY (recording_collection_id) REFERENCES recording_collections(id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recording_collection_artists (
    recording_collection_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    artist_id                 CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    position                  SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (recording_collection_id, artist_id),
    UNIQUE KEY uq_recording_collection_artists_position
        (recording_collection_id, position),
    KEY idx_recording_collection_artists_artist (artist_id),
    CONSTRAINT fk_recording_collection_artists_collection
        FOREIGN KEY (recording_collection_id) REFERENCES recording_collections(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_recording_collection_artists_artist
        FOREIGN KEY (artist_id) REFERENCES artists(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE recorded_concerts (
    id                       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    recording_collection_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    venue_id                 CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    position                 SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_recorded_concerts_position (recording_collection_id, position),
    KEY idx_recorded_concerts_collection (recording_collection_id),
    KEY idx_recorded_concerts_venue (venue_id),
    CONSTRAINT fk_recorded_concerts_collection
        FOREIGN KEY (recording_collection_id) REFERENCES recording_collections(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_recorded_concerts_venue
        FOREIGN KEY (venue_id) REFERENCES venues(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- API resource construction
-- =============================================================================
-- These SELECTs return one JSON document in a column named `resource`.
-- :api_base_url / :id below are shown as named application placeholders.
-- If the driver only supports positional parameters, replace them with ?.
--
-- `name` is deliberately NOT persisted. If the legacy/OpenAPI contract requires
-- it, the compatibility mapping below uses slug as the canonical machine name.
--
-- `latest_broadcast` means most recent broadcast that has started (starts_at <=
-- UTC_TIMESTAMP). If the contract instead means latest scheduled row, remove
-- that predicate.

-- -----------------------------------------------------------------------------
-- ProgramResource
-- -----------------------------------------------------------------------------

SELECT JSON_OBJECT(
    'id', p.id,
    'name', p.slug,
    'slug', p.slug,
    'title', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.title)
        FROM program_texts pt
        WHERE pt.program_id = p.id
    ), JSON_OBJECT()), '$'),
    'description', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.description)
        FROM program_texts pt
        WHERE pt.program_id = p.id
    ), JSON_OBJECT()), '$'),
    'genres', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', g.id,
                'slug', g.slug,
                'name', JSON_QUERY(
                             COALESCE(
                                (
                                 SELECT JSON_OBJECTAGG(
                                          gt.locale,
                                          gt.name
									    )
                                 FROM genre_texts gt
                                 WHERE gt.genre_id = g.id
                                ),
                                JSON_OBJECT()
                             ),
                             '$'
                 ),
                'position', pg.position
            ) ORDER BY pg.position
        )
        FROM program_genres pg
        JOIN genres g ON g.id = pg.genre_id
        WHERE pg.program_id = p.id
    ), JSON_ARRAY()), '$'),
    'categories', JSON_ARRAY(),
    'tags', JSON_ARRAY(),
    'latest_broadcast', JSON_QUERY((
        SELECT JSON_OBJECT(
            'id', b.id,
            'episode_id', b.episode_id,
            'starts_at', DATE_FORMAT(b.starts_at, '%Y-%m-%dT%H:%i:%s.%fZ'),
            'ends_at', DATE_FORMAT(b.ends_at, '%Y-%m-%dT%H:%i:%s.%fZ')
        )
        FROM broadcasts b
        JOIN episodes e2 ON e2.id = b.episode_id
        WHERE e2.program_id = p.id
          AND b.starts_at <= UTC_TIMESTAMP(6)
        ORDER BY b.starts_at DESC
        LIMIT 1
    ), '$'),
    'links', JSON_OBJECT(
        'self', CONCAT(:api_base_url, '/programs/', p.id),
        'episodes', CONCAT(:api_base_url, '/programs/', p.id, '/episodes')
    )
) AS resource
FROM programs p
WHERE p.id = :program_id;

-- -----------------------------------------------------------------------------
-- EpisodeResource
-- title and main genres are inherited from the program.
-- subtitle/description/content, subgenres, artists, editors, mood, image and
-- audio are episode-owned or episode-related.
-- -----------------------------------------------------------------------------

SELECT JSON_OBJECT(
    'id', e.id,
    'program_id', e.program_id,
    'name', e.slug,
    'slug', e.slug,
    'title', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.title)
        FROM program_texts pt
        WHERE pt.program_id = e.program_id
    ), JSON_OBJECT()), '$'),
    'subtitle', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(et.locale, et.subtitle)
        FROM episode_texts et
        WHERE et.episode_id = e.id
    ), JSON_OBJECT()), '$'),
    'description', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(et.locale, et.description)
        FROM episode_texts et
        WHERE et.episode_id = e.id
    ), JSON_OBJECT()), '$'),
    'content', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(
            et.locale,
            JSON_QUERY(et.content, '$')
        )
        FROM episode_texts et
        WHERE et.episode_id = e.id
    ), JSON_OBJECT()), '$'),
    'genres', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', g.id,
                'slug', g.slug,
                'name', JSON_QUERY(
                             COALESCE(
                                (
                                 SELECT JSON_OBJECTAGG(
                                          gt.locale,
                                          gt.name
									    )
                                 FROM genre_texts gt
                                 WHERE gt.genre_id = g.id
                                ),
                                JSON_OBJECT()
                             ),
                             '$'
                 ),
                'position', pg.position
            ) ORDER BY pg.position
        )
        FROM program_genres pg
        JOIN genres g ON g.id = pg.genre_id
        WHERE pg.program_id = e.program_id
    ), JSON_ARRAY()), '$'),
    'subgenres', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', sg.id,
                'genre_id', sg.genre_id,
                'slug', sg.slug,
                'name', sg.name,
                'position', es.position
            ) ORDER BY es.position
        )
        FROM episode_subgenres es
        JOIN subgenres sg ON sg.id = es.subgenre_id
        WHERE es.episode_id = e.id
    ), JSON_ARRAY()), '$'),
    'artists', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', a.id,
                'name', a.name,
                'position', ea.position
            ) ORDER BY ea.position
        )
        FROM episode_artists ea
        JOIN artists a ON a.id = ea.artist_id
        WHERE ea.episode_id = e.id
    ), JSON_ARRAY()), '$'),
    'editors', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', ed.id,
                'name', ed.name,
                'role', ee.role,
                'position', ee.position
            ) ORDER BY ee.position
        )
        FROM episode_editors ee
        JOIN editors ed ON ed.id = ee.editor_id
        WHERE ee.episode_id = e.id
    ), JSON_ARRAY()), '$'),
    'mood', JSON_OBJECT(
        'wave', e.mood_wave,
        'color', e.mood_color,
        'tempo', e.mood_tempo,
        'intensity', e.mood_intensity
    ),
    'image', JSON_QUERY(CASE
        WHEN i.id IS NULL THEN NULL
        ELSE JSON_OBJECT(
            'id', i.id,
            'url', i.url,
            'alt_text', i.alt_text,
            'mime_type', i.mime_type,
            'width', i.width_px,
            'height', i.height_px
        )
    END, '$'),
    'audio', JSON_QUERY(CASE
        WHEN af.id IS NULL THEN NULL
        ELSE JSON_OBJECT(
            'id', af.id,
            'url', af.url,
            'name', af.file_name,
            'mime_type', af.mime_type,
            'duration', af.duration_seconds
        )
    END, '$'),
    'broadcasts', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', b.id,
                'starts_at', DATE_FORMAT(b.starts_at, '%Y-%m-%dT%H:%i:%s.%fZ'),
                'ends_at', DATE_FORMAT(b.ends_at, '%Y-%m-%dT%H:%i:%s.%fZ')
            ) ORDER BY b.starts_at
        )
        FROM broadcasts b
        WHERE b.episode_id = e.id
    ), JSON_ARRAY()), '$'),
    'latest_broadcast', JSON_QUERY((
        SELECT JSON_OBJECT(
            'id', b.id,
            'starts_at', DATE_FORMAT(b.starts_at, '%Y-%m-%dT%H:%i:%s.%fZ'),
            'ends_at', DATE_FORMAT(b.ends_at, '%Y-%m-%dT%H:%i:%s.%fZ')
        )
        FROM broadcasts b
        WHERE b.episode_id = e.id
          AND b.starts_at <= UTC_TIMESTAMP(6)
        ORDER BY b.starts_at DESC
        LIMIT 1
    ), '$'),
    'categories', JSON_ARRAY(),
    'tags', JSON_ARRAY(),
    'links', JSON_OBJECT(
        'self', CONCAT(:api_base_url, '/episodes/', e.id),
        'program', CONCAT(:api_base_url, '/programs/', e.program_id),
        'broadcasts', CONCAT(:api_base_url, '/episodes/', e.id, '/broadcasts')
    )
) AS resource
FROM episodes e
LEFT JOIN images i ON i.id = e.image_id
LEFT JOIN audio_files af ON af.id = e.audio_id
WHERE e.id = :episode_id;

-- -----------------------------------------------------------------------------
-- BroadcastResource
-- Storage is minimal. The resource can still inherit presentational fields from
-- episode/program without copying them into broadcasts.
-- -----------------------------------------------------------------------------

SELECT JSON_OBJECT(
    'id', b.id,
    'episode_id', b.episode_id,
    'starts_at', DATE_FORMAT(b.starts_at, '%Y-%m-%dT%H:%i:%s.%fZ'),
    'ends_at', DATE_FORMAT(b.ends_at, '%Y-%m-%dT%H:%i:%s.%fZ'),
    'title', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.title)
        FROM program_texts pt
        WHERE pt.program_id = e.program_id
    ), JSON_OBJECT()), '$'),
    'subtitle', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(et.locale, et.subtitle)
        FROM episode_texts et
        WHERE et.episode_id = e.id
    ), JSON_OBJECT()), '$'),
    'mood', JSON_OBJECT(
        'wave', e.mood_wave,
        'color', e.mood_color,
        'tempo', e.mood_tempo,
        'intensity', e.mood_intensity
    ),
    'image', JSON_QUERY(CASE
        WHEN i.id IS NULL THEN NULL
        ELSE JSON_OBJECT(
            'id', i.id,
            'url', i.url,
            'alt_text', i.alt_text,
            'mime_type', i.mime_type,
            'width', i.width_px,
            'height', i.height_px
        )
    END, '$'),
    'links', JSON_OBJECT(
        'self', CONCAT(:api_base_url, '/broadcasts/', b.id),
        'episode', CONCAT(:api_base_url, '/episodes/', e.id),
        'program', CONCAT(:api_base_url, '/programs/', e.program_id)
    )
) AS resource
FROM broadcasts b
JOIN episodes e ON e.id = b.episode_id
LEFT JOIN images i ON i.id = e.image_id
WHERE b.id = :broadcast_id;

-- -----------------------------------------------------------------------------
-- PostResource
-- -----------------------------------------------------------------------------

SELECT JSON_OBJECT(
    'id', p.id,
    'name', p.slug,
    'slug', p.slug,
    'title', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.title)
        FROM post_texts pt
        WHERE pt.post_id = p.id
    ), JSON_OBJECT()), '$'),
    'description', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(pt.locale, pt.description)
        FROM post_texts pt
        WHERE pt.post_id = p.id
    ), JSON_OBJECT()), '$'),
    'content', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(
            pt.locale,
            JSON_QUERY(pt.content, '$')
        )
        FROM post_texts pt
        WHERE pt.post_id = p.id
    ), JSON_OBJECT()), '$'),
    'categories', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', c.id,
                'slug', c.slug,
                'name', c.name,
                'position', pc.position
            ) ORDER BY pc.position
        )
        FROM post_categories pc
        JOIN categories c ON c.id = pc.category_id
        WHERE pc.post_id = p.id
    ), JSON_ARRAY()), '$'),
    'tags', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', t.id,
                'slug', t.slug,
                'name', t.name,
                'position', ptg.position
            ) ORDER BY ptg.position
        )
        FROM post_tags ptg
        JOIN tags t ON t.id = ptg.tag_id
        WHERE ptg.post_id = p.id
    ), JSON_ARRAY()), '$'),
    'links', JSON_OBJECT(
        'self', CONCAT(:api_base_url, '/posts/', p.id)
    )
) AS resource
FROM posts p
WHERE p.id = :post_id;

-- -----------------------------------------------------------------------------
-- RecordingCollectionResource (ConcertPodium)
-- -----------------------------------------------------------------------------

SELECT JSON_OBJECT(
    'id', rc.id,
    'name', rc.slug,
    'slug', rc.slug,
    'title', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(rct.locale, rct.title)
        FROM recording_collection_texts rct
        WHERE rct.recording_collection_id = rc.id
    ), JSON_OBJECT()), '$'),
    'description', JSON_QUERY(COALESCE((
        SELECT JSON_OBJECTAGG(rct.locale, rct.description)
        FROM recording_collection_texts rct
        WHERE rct.recording_collection_id = rc.id
    ), JSON_OBJECT()), '$'),
    'artists', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', a.id,
                'name', a.name,
                'position', rca.position
            ) ORDER BY rca.position
        )
        FROM recording_collection_artists rca
        JOIN artists a ON a.id = rca.artist_id
        WHERE rca.recording_collection_id = rc.id
    ), JSON_ARRAY()), '$'),
    'concerts', JSON_QUERY(COALESCE((
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id', rco.id,
                'position', rco.position,
                'venue', JSON_OBJECT(
                    'id', v.id,
                    'name', v.name,
                    'city', v.city,
                    'address', v.address,
                    'country_code', v.country_code
                )
            ) ORDER BY rco.position
        )
        FROM recorded_concerts rco
        JOIN venues v ON v.id = rco.venue_id
        WHERE rco.recording_collection_id = rc.id
    ), JSON_ARRAY()), '$'),
    'links', JSON_OBJECT(
        'self', CONCAT(:api_base_url, '/recording-collections/', rc.id)
    )
) AS resource
FROM recording_collections rc
WHERE rc.id = :recording_collection_id;

-- -----------------------------------------------------------------------------
-- Integrity / migration validation queries
-- -----------------------------------------------------------------------------

-- Programs that do not have any genre.
SELECT
    p.id,
    p.slug,
    COUNT(pg.genre_id) AS genre_count
FROM programs p
LEFT JOIN program_genres pg
    ON pg.program_id = p.id
GROUP BY
    p.id,
    p.slug
HAVING COUNT(pg.genre_id) = 0;

-- Any invalid episode/subgenre pairing (should remain empty if triggers are used).
SELECT
    es.episode_id,
    es.subgenre_id,
    e.program_id,
    sg.genre_id AS subgenre_genre_id
FROM episode_subgenres es
JOIN episodes e ON e.id = es.episode_id
JOIN subgenres sg ON sg.id = es.subgenre_id
LEFT JOIN program_genres pg
  ON pg.program_id = e.program_id
 AND pg.genre_id = sg.genre_id
WHERE pg.program_id IS NULL;

-- Broadcast rows whose timing is invalid (also protected by CHECK constraint).
SELECT id, episode_id, starts_at, ends_at
FROM broadcasts
WHERE ends_at <= starts_at;
