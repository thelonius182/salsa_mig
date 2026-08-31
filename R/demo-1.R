compat_programs |>
  dplyr::filter(program_id == 17016)

compat_program_terms |>
  dplyr::filter(program_id == 17016) |>
  dplyr::arrange(locale, term_id)

files <- list.files("R", full.names = TRUE)

hits <- lapply(files, function(file) {
  lines <- readLines(file, warn = FALSE)
  idx <- grep("compat_program", lines)
  
  if (length(idx) > 0) {
    data.frame(
      file = basename(file),
      line = idx,
      text = lines[idx]
    )
  }
})

dplyr::bind_rows(hits)

files <- list.files(".", pattern = "\\.[Rr]$", recursive = TRUE, full.names = TRUE)

hits <- lapply(files, function(file) {
  lines <- readLines(file, warn = FALSE)
  idx <- grep("historical_program_terms|in_scope_program_terms", lines)
  
  if (length(idx)) {
    data.frame(
      file = file,
      line = idx,
      text = lines[idx]
    )
  }
})

dplyr::bind_rows(hits)