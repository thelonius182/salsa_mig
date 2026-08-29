pacman::p_load(DBI, RMariaDB, dplyr, tidyr, purrr, stringr, jsonlite, openssl, igraph)

source("R/foundation.R")
source("R/programs.R")
source("R/broadcasts.R")
source("R/episodes.R")
source("R/genres.R")
source("R/credits.R")
source("R/media.R")
source("R/content.R")
source("R/wordpress_adapters.R")
source("R/posts.R")
source("R/recordings.R")
source("R/wp_terms_readr_helpr.R")

# Temporary: preserve the current development-script behavior.
# Once orchestration is introduced, tests should run separately from the sync entry point.
source("tests/migration_regression_tests.R")
