source("scripts/00_functions.R")

comparison_dir <- "provenance/upstream_comparison"
primary <- load_dp_data("primary")
historical <- load_dp_data("historical")$dpdat
keys <- c("dpnum", "caseid")
stopifnot(!anyDuplicated(primary$dpdat[keys]), !anyDuplicated(historical[keys]))
matched <- primary$dpdat |>
  left_join(
    historical |>
      select(all_of(keys), historical_education = bettered, historical_income = highinc) |>
      mutate(historical_match = TRUE),
    by = keys, relationship = "one-to-one"
  ) |>
  mutate(historical_match = coalesce(historical_match, FALSE))
restored <- primary
restored$dpdat$bettered[matched$historical_match] <-
  matched$historical_education[matched$historical_match]
restored$dpdat$highinc[matched$historical_match] <-
  matched$historical_income[matched$historical_match]
held_fixed <- setdiff(names(primary$dpdat), c("bettered", "highinc"))
stopifnot(
  nrow(primary$dpdat) == 5824L,
  sum(matched$historical_match) == 5822L,
  identical(primary$dpdat[held_fixed], restored$dpdat[held_fixed]),
  identical(primary$att_indices, restored$att_indices),
  all(matched$upstream_poll_id[!matched$historical_match] == "btp-general-election-2004")
)

changes <- map_dfr(c("bettered", "highinc"), function(field) {
  old <- restored$dpdat[[field]]
  current <- primary$dpdat[[field]]
  tibble(
    poll_id = matched$upstream_poll_id, field,
    historical_match = matched$historical_match,
    changed = xor(is.na(old), is.na(current)) |
      (!is.na(old) & !is.na(current) & old != current),
    historical_missing = is.na(old), current_missing = is.na(current),
    missingness_changed = xor(is.na(old), is.na(current))
  )
}) |>
  summarise(
    participants = n(), matched_people = sum(historical_match),
    unchanged_unmatched_people = sum(!historical_match), changed = sum(changed),
    historical_missing = sum(historical_missing), current_missing = sum(current_missing),
    missingness_changed = sum(missingness_changed), .by = c(poll_id, field)
  )

files <- list.files("tabs", full.names = TRUE)
hashes <- function() vapply(files, digest::digest, character(1), algo = "sha256", file = TRUE)
before <- hashes()
results <- map_dfr(c("historical_flags", "current_flags"), function(scenario) {
  input <- if (scenario == "historical_flags") restored else primary
  output <- new.env(parent = emptyenv())
  analysis <- new.env(parent = globalenv())
  analysis$load_dp_data <- function(...) input
  analysis$write.csv <- function(x, file, ...) output[[file]] <- x
  source("scripts/02_domination.R", local = analysis)
  map_dfr(c("educ", "income", "triple"), function(dimension) {
    pairs <- output[[sprintf("tabs/03_dom_%s_by_group_issue.csv", dimension)]]
    map_dfr(c("D", "Db"), function(measure) {
      field <- if (measure == "D") "ext_grp" else "freqgrp_grp"
      null <- if (measure == "D") 0 else .5
      observations <- pairs |>
        transmute(poll_id, value = as.numeric(.data[[field]])) |>
        filter(is.finite(value))
      fit <- lm(I(value - null) ~ 1, data = observations)
      interval <- clubSandwich::conf_int(fit,
        vcov = "CR2", cluster = observations$poll_id,
        test = "Satterthwaite", p_values = TRUE
      )
      tibble(
        scenario, dimension, measure, estimate = interval$beta + null,
        se = interval$SE, df = interval$df,
        conf_low = interval$CI_L + null, conf_high = interval$CI_U + null,
        p = interval$p_val, participants = nrow(input$dpdat),
        n_pairs = nrow(observations), n_polls = n_distinct(observations$poll_id)
      )
    })
  })
})
stopifnot(identical(before, hashes()))
expected <- read.csv(file.path(comparison_dir, "estimates.csv")) |>
  filter(stage == "primary") |>
  select(key = measure, expected_estimate = estimate, expected_p = p, expected_n = n_pairs)
verified <- results |>
  filter(scenario == "current_flags") |>
  mutate(key = paste(dimension, measure, sep = "_")) |>
  left_join(expected, by = "key", relationship = "one-to-one")
stopifnot(
  nrow(verified) == 6L, !anyNA(verified$expected_estimate),
  max(abs(verified$estimate - verified$expected_estimate)) < 1e-12,
  max(abs(verified$p - verified$expected_p)) < 1e-12,
  identical(verified$n_pairs, verified$expected_n)
)
write.csv(results, file.path(comparison_dir, "subgroup_only_estimates.csv"), row.names = FALSE)
write.csv(changes, file.path(comparison_dir, "subgroup_only_changes.csv"), row.names = FALSE)
message("All 5,824 people and non-subgroup fields retained; all primary table hashes unchanged.")
