library(stringr)
library(readr)

html <- read_lines("https://api.concertzender.nl/docs/api") |>
  paste(collapse = "\n")

openapi_json <- str_match(
  html,
  regex(
    "docs\\.apiDescriptionDocument\\s*=\\s*(\\{.*?\\});",
    dotall = TRUE
  )
)[, 2]

write_lines(
  openapi_json,
  "docs/reference/concertzender-openapi-0.0.1.json"
)

library(jsonlite)

openapi <- fromJSON(
  "docs/reference/concertzender-openapi-0.0.1.json",
  simplifyVector = FALSE
)

c(
  paths = length(openapi$paths),
  schemas = length(openapi$components$schemas)
)
