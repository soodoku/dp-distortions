pooled_results <- scores |>
  group_by(format, construct, timing_class, membership, metric) |>
  group_modify(\(d, keys) map_dfr(c("pairs", "equal_family_event"), \(w) pool_scores(d, w))) |>
  ungroup()

family_results <- scores |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(family_id, format, construct, timing_class, membership, metric)
  )

leave_family_out <- scores |>
  group_by(format, construct, timing_class, membership, metric) |>
  group_modify(\(d, keys) {
    families <- unique(d$family_id)
    map_dfr(families, \(omit) {
      map_dfr(c("pairs", "equal_family_event"), \(w) {
        pool_scores(filter(d, family_id != omit), w) |> mutate(omitted_family = omit)
      })
    })
  }) |>
  ungroup()

readr::write_csv(pooled_results, "oos_replication/tabs/pooled_results.csv")
readr::write_csv(family_results, "oos_replication/tabs/family_results.csv")
readr::write_csv(leave_family_out, "oos_replication/tabs/leave_family_out.csv")

source_register <- readr::read_csv("oos_replication/source_register.csv", show_col_types = FALSE)
study_results <- scores |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(source, format, construct, timing_class, membership, metric)
  ) |>
  left_join(select(source_register, source = url, title),
    by = "source", relationship = "many-to-one"
  )
stopifnot(!anyNA(study_results$title))
readr::write_csv(study_results, "oos_replication/tabs/study_results.csv")

original_comparison <- readr::read_csv(
  "tabs/09_paired_response_sensitivity.csv", show_col_types = FALSE
) |>
  select(measure, membership = sample, mean = estimate, pairs = n_pairs, polls = n_polls)
readr::write_csv(original_comparison, "oos_replication/tabs/original_comparison.csv")

hp_table <- study_results |>
  filter(metric %in% c("h", "p", "p_absolute")) |>
  select(title, format, construct, membership, metric, mean, pairs) |>
  pivot_wider(names_from = metric, values_from = c(mean, pairs))
d_table <- study_results |>
  filter(startsWith(metric, "d_"), pairs > 0) |>
  select(title, format, construct, membership, metric, pairs, mean, positive_fraction)
writeLines(c(
  "# Results for the currently verified sources", "",
  "Search and source verification remain open; this is not the final corpus.", "",
  "Scores use the 0–1 instrument scale. Positive H means lower within-group SD;",
  "positive directional P means movement outward along the initial midpoint direction;",
  "positive D means movement toward the initial advantaged-subgroup reference.",
  "Absolute P instead compares absolute distances from the midpoint, including crossings.", "",
  "Group P is not the difference between political parties' or religious groups' affect.",
  "H measures dispersion inside the actual discussion group. Directional and absolute",
  "P can have opposite signs; these are distinct measurements, not coding discrepancies.", "",
  "Paired respondents are primary for the extension. Available-wave responses give",
  "the direct bridge to the corrected original. Each mean weights eligible group-item",
  "pairs equally. Pair counts differ by metric; missing directions are not zeros.", "",
  "No format/timing stratum yet has adequate independent families for pooled inference.",
  "A1R2019 and A1R Climate share participants. The 19 OBOE sites share one synchronous",
  "national event. Hong Kong has one group per discussion format. Tanzania's",
  "February-to-May window includes March information sessions and April deliberation.",
  "Echo's baseline precedes its discussion by 1–82 days; immediate refers to its post-wave.", "",
  "## Homogenization and polarization", "",
  as.character(knitr::kable(hp_table, format = "pipe", digits = 4)), "",
  "## Whole-group domination", "",
  "Unavailable dimensions are omitted here and retained as zero eligible pairs in the CSV.", "",
  as.character(knitr::kable(d_table, format = "pipe", digits = 4)), "",
  "## Corrected original benchmark", "",
  as.character(knitr::kable(original_comparison, format = "pipe", digits = 4)), "",
  "The original uses attitude indices, while these sources use individual items.",
  "Differences therefore combine setting, sample, timing and measurement; they are",
  "not estimates of a causal difference between deliberative formats.", "",
  "Event results, minimum-five sensitivities, family weighting and leave-one-family-out",
  "results are in the accompanying CSV files. Dates and source limitations are in the",
  "event metadata and source register. Neither the manuscript nor corrigendum is revised."
), "oos_replication/tabs/results.md")

whatsapp_flagged <- whatsapp_participants |>
  filter(maybe_duplicate_friend == 1) |>
  pull(s1.ResponseId)
stopifnot(length(whatsapp_flagged) == 52L)
whatsapp_sensitivity <- map_dfr(c("paired", "available"), \(sample) {
  score_groups(filter(whatsapp, !participant_id %in% whatsapp_flagged), sample)
}) |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(event_id, construct, membership, metric)
  ) |>
  mutate(specification = "exclude_flagged_respondents") |>
  bind_rows(event_results |>
      filter(startsWith(event_id, "whatsapp_")) |>
      select(event_id, construct, membership, metric, pairs, mean, positive_fraction) |>
      mutate(specification = "primary")
  )
readr::write_csv(whatsapp_sensitivity, "oos_replication/tabs/whatsapp_identity_sensitivity.csv")
