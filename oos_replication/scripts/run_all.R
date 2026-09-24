source("scripts/00_functions.R")
source("oos_replication/scripts/metrics.R")
dir.create("oos_replication/data", showWarnings = FALSE)
dir.create("oos_replication/tabs", showWarnings = FALSE)

files <- oos_source_manifest()
walk(files$file, oos_source_path)

source("oos_replication/scripts/prepare_a1r.R")
source("oos_replication/scripts/prepare_oboe.R")
source("oos_replication/scripts/prepare_hongkong.R")
source("oos_replication/scripts/prepare_tanzania.R")
source("oos_replication/scripts/prepare_climate.R")
source("oos_replication/scripts/prepare_celaya.R")
source("oos_replication/scripts/prepare_echo.R")
source("oos_replication/scripts/prepare_whatsapp.R")
source("oos_replication/scripts/prepare_cross_party.R")
source("oos_replication/scripts/prepare_consensus.R")
source("oos_replication/scripts/prepare_diplomacy.R")
source("oos_replication/scripts/prepare_shizuoka.R")
ratings <- bind_rows(
  a1r, oboe, hongkong, tanzania, climate, celaya, echo, whatsapp, cross_party, consensus,
  diplomacy, shizuoka
)
events <- readr::read_csv("oos_replication/events.csv", show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
stopifnot(
  !anyDuplicated(events$event_id),
  all(ratings$event_id %in% events$event_id)
)

scores <- map_dfr(c("paired", "available"), \(sample) score_groups(ratings, sample)) |>
  left_join(events, by = "event_id", relationship = "many-to-one")

event_results <- scores |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(event_id, family_id, format, construct, membership, metric)
  )
minimum_five <- scores |>
  mutate(
    estimate = if_else(n_pre >= 5 & n_post >= 5, estimate, NA_real_),
    positive = if_else(n_pre >= 5 & n_post >= 5, positive, NA)
  ) |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(event_id, family_id, format, construct, membership, metric)
  )

readr::write_csv(source_flow, "oos_replication/tabs/sample_flow.csv")
saveRDS(scores, "oos_replication/data/group_results.rds")
readr::write_csv(event_results, "oos_replication/tabs/event_results.csv")
readr::write_csv(minimum_five, "oos_replication/tabs/minimum_five.csv")
source("oos_replication/scripts/demographics.R")
source("oos_replication/scripts/summarize.R")
saveRDS(ratings, "oos_replication/data/ratings.rds")
writeLines(trimws(capture.output(sessionInfo()), which = "right"),
  "oos_replication/tabs/session_info.txt"
)
print(event_results, n = 12)
