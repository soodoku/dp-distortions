source("scripts/00_functions.R")
dir.create("oos_replication/data", showWarnings = FALSE)
queries <- c(
  "deliberat*",
  '"citizens assembly" OR "citizens jury" OR "mini-public"',
  'polarization AND (discussion OR group OR "echo chamber")'
)
search_log <- map_dfr(seq_along(queries), \(i) {
  start <- 0L
  hits <- list()
  repeat {
    url <- paste0(
      "https://dataverse.harvard.edu/api/search?q=", URLencode(queries[i], reserved = TRUE),
      "&type=dataset&per_page=1000&start=", start
    )
    path <- sprintf("oos_replication/data/search_%s_%s.json", i, start)
    download.file(url, path, mode = "wb", quiet = TRUE)
    page <- jsonlite::fromJSON(path)$data
    if (page$total_count == 0L) break
    stopifnot(page$count_in_response > 0L)
    hits[[length(hits) + 1L]] <- tibble(
      doi = page$items$global_id, title = page$items$name, url = page$items$url
    )
    start <- start + page$count_in_response
    if (start >= page$total_count) break
  }
  records <- bind_rows(tibble(doi = character(), title = character(), url = character()), hits) |>
    distinct(doi, .keep_all = TRUE)
  readr::write_csv(records, sprintf("oos_replication/data/search_%s.csv", i))
  tibble(
    searched = as.character(Sys.Date()),
    archive = "Harvard Dataverse (including harvested records)",
    query = queries[i], records = nrow(records), url = url,
    status = "retrieved; eligibility requires source-register screening"
  )
})
previous <- readr::read_csv("oos_replication/search_log.csv", show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character(), records = readr::col_double())
)
readr::write_csv(bind_rows(previous, search_log) |> distinct(), "oos_replication/search_log.csv")
print(search_log)
