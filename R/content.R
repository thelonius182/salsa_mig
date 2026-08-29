split_wordpress_content <- function(content) {
  content <- as.character(content)
  
  more_pattern <- "<!--more(?:\\s+.*?)?-->"
  
  marker_count <- str_count(replace_na(content, ""),
                            regex(more_pattern, ignore_case = TRUE))
  
  if (any(marker_count > 1L)) {
    stop("Multiple <!--more--> markers found in WordPress content")
  }
  
  has_more <- marker_count == 1L
  
  description <- if_else(has_more, str_extract(content, regex(
    paste0("^.*?(?=", more_pattern, ")"),
    ignore_case = TRUE,
    dotall = TRUE
  )), NA_character_)
  
  body <- if_else(has_more, str_replace(content, regex(
    paste0("^.*?", more_pattern),
    ignore_case = TRUE,
    dotall = TRUE
  ), ""), content)
  
  tibble(description = clean_optional_text(description),
         content = clean_optional_text(body))
}

build_content_json <- function(content_raw) {
  content_raw <- clean_optional_text(content_raw)
  
  map_chr(content_raw, \(value) {
    if (is.na(value)) {
      return(NA_character_)
    }
    
    toJSON(list(format = "html", value = value), auto_unbox = TRUE)
  })
}

convert_wordpress_captions <- function(content) {
  content <- as.character(content)
  
  map_chr(content, \(value) {
    if (is.na(value)) {
      return(NA_character_)
    }
    
    open_count <- str_count(value, regex("\\[caption\\b", ignore_case = TRUE))
    
    close_count <- str_count(value, regex("\\[/caption\\]", ignore_case = TRUE))
    
    if (open_count != close_count) {
      stop("Unbalanced WordPress caption shortcode")
    }
    
    value |>
      str_replace_all(regex("\\[caption\\b([^\\]]*)\\]", ignore_case = TRUE),
                      \(opening) {
                        align <- str_match(opening,
                                           regex("\\balign=[\"']([^\"']+)[\"']", ignore_case = TRUE))[, 2]
                        
                        if (is.na(align)) {
                          align <- "alignnone"
                        }
                        
                        if (!align %in% c("alignnone", "alignleft", "alignright", "aligncenter")) {
                          stop("Unexpected WordPress caption alignment: ", align)
                        }
                        
                        paste0('<figure class="wp-caption ', align, '">')
                      }) |>
      str_replace_all(regex("\\[/caption\\]", ignore_case = TRUE), "</figure>")
  })
}

normalize_wordpress_html <- function(content) {
  content |>
    clean_optional_text() |>
    convert_wordpress_captions()
}

prepare_wordpress_content <- function(content) {
  parts <- split_wordpress_content(content)
  
  parts |>
    mutate(content = normalize_wordpress_html(content))
}

