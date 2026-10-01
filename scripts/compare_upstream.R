source("scripts/00_functions.R")

comparison_dir <- "provenance/upstream_comparison"
dir.create(comparison_dir, recursive = TRUE, showWarnings = FALSE)
original_stage <- getOption("dp.input_stage")
results <- list()
cohorts <- list()
for (stage in dp_input_stages) {
  options(dp.input_stage = stage)
  output <- new.env(parent = emptyenv())
  analysis <- new.env(parent = globalenv())
  analysis$write.csv <- function(x, file, ...) {
    output[[file]] <- x
  }
  source("scripts/01_hom_pol.R", local = analysis)
  source("scripts/02_domination.R", local = analysis)
  dat <- load_dp_data()
  cohorts[[stage]] <- dat$dpdat |>
    summarise(participants = n(), groups = n_distinct(group_key), .by = c(dpnum, pollname)) |>
    mutate(stage, .before = 1)
  hp <- output[["tabs/03_hom_pol_by_group_issue.csv"]]
  outcomes <- list(
    hp |> transmute(poll_id, group_key, issue_id, measure = "H", value = homoex, null = 0),
    hp |> transmute(poll_id, group_key, issue_id, measure = "Hb", value = homofreq, null = .5),
    hp |> transmute(poll_id, group_key, issue_id, measure = "P", value = polarex, null = 0),
    hp |> transmute(poll_id, group_key, issue_id, measure = "Pb", value = polarfreq, null = .5)
  )
  for (dimension in c("gender", "educ", "income", "triple")) {
    d <- output[[sprintf("tabs/03_dom_%s_by_group_issue.csv", dimension)]]
    outcomes <- c(outcomes, list(
      d |> transmute(poll_id, group_key, issue_id,
        measure = paste0(dimension, "_D"), value = ext_grp, null = 0
      ),
      d |> transmute(poll_id, group_key, issue_id,
        measure = paste0(dimension, "_Db"), value = freqgrp_grp, null = .5
      )
    ))
  }
  values <- bind_rows(outcomes) |> filter(is.finite(value))
  write.csv(values, file.path(comparison_dir, paste0(stage, "_pairs.csv")), row.names = FALSE)
  results[[stage]] <- values |>
    nest(.by = c(measure, null)) |>
    mutate(result = map2(data, null, function(d, target) {
      fit <- lm(I(value - target) ~ 1, data = d)
      interval <- clubSandwich::conf_int(fit,
        vcov = "CR2", cluster = d$poll_id, test = "Satterthwaite", p_values = TRUE
      )
      tibble(
        estimate = interval$beta + target, se = interval$SE, df = interval$df,
        conf_low = interval$CI_L + target, conf_high = interval$CI_U + target,
        p = interval$p_val, n_pairs = nrow(d), n_polls = n_distinct(d$poll_id)
      )
    })) |>
    select(-data) |>
    unnest(result) |>
    mutate(stage, .before = 1)
}
options(dp.input_stage = original_stage)
write.csv(bind_rows(results), file.path(comparison_dir, "estimates.csv"), row.names = FALSE)
write.csv(bind_rows(cohorts), file.path(comparison_dir, "cohorts.csv"), row.names = FALSE)

values <- map_dfr(dp_input_stages, function(stage) {
  read.csv(file.path(comparison_dir, paste0(stage, "_pairs.csv"))) |>
    mutate(stage)
})
by_poll <- values |>
  summarise(estimate = mean(value), n_pairs = n(), .by = c(stage, poll_id, measure))
write.csv(by_poll, file.path(comparison_dir, "estimates_by_poll.csv"), row.names = FALSE)
old <- load_dp_data("historical")$dpdat
new <- load_dp_data("corrected")$dpdat
comparison <- old |>
  select(dpnum, caseid, female, bettered, highinc, hhincome) |>
  inner_join(new |> select(dpnum, caseid, female, bettered, highinc, hhincome),
    by = c("dpnum", "caseid"), suffix = c("_old", "_new"), relationship = "one-to-one"
  )
changes <- map_dfr(c("female", "bettered", "highinc", "hhincome"), function(field) {
  x <- comparison[[paste0(field, "_old")]]
  y <- comparison[[paste0(field, "_new")]]
  tibble(
    dpnum = comparison$dpnum, field,
    changed = xor(is.na(x), is.na(y)) | (!is.na(x) & !is.na(y) & x != y),
    missing_changed = xor(is.na(x), is.na(y))
  )
}) |>
  summarise(changed = sum(changed), missing_changed = sum(missing_changed), .by = c(dpnum, field))
write.csv(changes, file.path(comparison_dir, "subgroup_changes.csv"), row.names = FALSE)
