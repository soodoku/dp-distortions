# Conditional comparisons for the corrigendum. Run from the repository root:
# Rscript scripts/checks.R
# Standalone runs write the two audit summaries; sourcing only computes and checks.

source("scripts/00_functions.R", local = TRUE)
domination_pairs <- map(c("gender", "educ", "income", "triple"), \(dimension) {
  read.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", dimension))
}) |>
  list_rbind()
recomputed <- domination_pairs |>
  mutate(
    d = signed_move(grp_t1, grp_t2, adv_t1),
    dis = signed_move(dis_t1, dis_t2, adv_t1),
    adv = -signed_move(adv_t1, adv_t2, dis_t1)
  )
stopifnot(
  isTRUE(all.equal(recomputed$d, domination_pairs$ext_grp)),
  isTRUE(all.equal(recomputed$dis, domination_pairs$ext_dis)),
  isTRUE(all.equal(recomputed$adv, domination_pairs$ext_adv))
)
scenarios <- bind_rows(
  domination_pairs |> mutate(scenario = "missing"),
  domination_pairs |> mutate(across(c(adv_t1, dis_t1, adv_t2, dis_t2), \(x) replace_na(x, 0)),
    scenario = "zero"
  )
) |>
  mutate(
    D = signed_move(grp_t1, grp_t2, adv_t1),
    dM = signed_move(dis_t1, dis_t2, adv_t1),
    aM = -signed_move(adv_t1, adv_t2, dis_t1),
    Db = as.numeric(movement_frequency(D))
  ) |>
  select(dimension, scenario, poll_id, group_key, pair_id, D, dM, aM, Db) |>
  pivot_longer(c(D, dM, aM, Db), names_to = "measure", values_to = "score")
missing_results <- scenarios |>
  filter(!is.na(score)) |>
  mutate(null = if_else(measure == "Db", .5, 0), y = score - null) |>
  nest(.by = c(dimension, scenario, measure)) |>
  mutate(result = map(data, \(observations) {
    model <- lm(y ~ 1, data = observations)
    clubSandwich::conf_int(model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite", p_values = TRUE
    ) |>
      as_tibble() |>
      transmute(
        estimate = beta + first(observations$null),
        conf_low = CI_L + first(observations$null),
        conf_high = CI_U + first(observations$null), p = p_val,
        n = nrow(observations)
      )
  })) |>
  select(-data) |>
  unnest(result)
released_subgroups <- read.csv("tabs/03_table_3.csv") |>
  mutate(dimension = recode(dimension,
    Gender = "gender", Education = "educ",
    Income = "income", "Gender, education, and income" = "triple"
  )) |>
  select(dimension, measure, released_estimate = estimate, released_p = p, n_pairs)
baseline_checks <- missing_results |>
  filter(scenario == "missing") |>
  left_join(released_subgroups, by = c("dimension", "measure"), relationship = "one-to-one")
stopifnot(
  nrow(baseline_checks) == 16, !anyNA(baseline_checks$released_estimate),
  max(abs(baseline_checks$estimate - baseline_checks$released_estimate)) < 1e-12,
  max(abs(baseline_checks$p - baseline_checks$released_p)) < 1e-10,
  all(baseline_checks$n == baseline_checks$n_pairs)
)
missing_mean_comparison <- missing_results |>
  pivot_wider(names_from = scenario, values_from = c(estimate, conf_low, conf_high, p, n)) |>
  mutate(change = estimate_missing - estimate_zero)


# Reference ties and valid zeros.
missing_means <- domination_pairs |>
  summarise(
    missing_subgroup = sum(if_any(c(adv_t1, dis_t1, adv_t2, dis_t2), is.na)),
    missing_d = sum(!complete.cases(grp_t1, grp_t2, adv_t1)),
    .by = dimension
  )
stopifnot(
  identical(missing_means$missing_subgroup, c(0L, 6L, 5L, 16L)),
  identical(missing_means$missing_d, c(0L, 1L, 1L, 6L))
)
zero_handling <- domination_pairs |>
  mutate(
    tied_start = coalesce(reference_tie, FALSE) & complete.cases(grp_t1, grp_t2, adv_t1),
    tied_as_zero = if_else(tied_start, 0, ext_grp),
    valid_zero = !is.na(ext_grp) & ext_grp == 0,
    old_zero_rules = if_else(valid_zero, NA_real_, tied_as_zero)
  ) |>
  summarise(
    tied_starts = sum(tied_start), valid_zeros = sum(valid_zero),
    n_valid = sum(!is.na(ext_grp)),
    mean_ties_as_zero = mean(tied_as_zero, na.rm = TRUE),
    mean_corrected = mean(ext_grp, na.rm = TRUE),
    positive_ties_as_zero = mean(tied_as_zero > 0, na.rm = TRUE),
    positive_corrected = mean(ext_grp > 0, na.rm = TRUE),
    mean_old_zero_rules = mean(old_zero_rules, na.rm = TRUE),
    positive_old_zero_rules = mean(old_zero_rules > 0, na.rm = TRUE),
    .by = dimension
  ) |>
  mutate(
    mean_change_ties = mean_corrected - mean_ties_as_zero,
    frequency_change_ties_pp = 100 * (positive_corrected - positive_ties_as_zero),
    mean_change_both = mean_corrected - mean_old_zero_rules,
    frequency_change_both_pp = 100 * (positive_corrected - positive_old_zero_rules)
  )
stopifnot(
  identical(zero_handling$tied_starts, c(40L, 51L, 17L, 11L)),
  identical(zero_handling$valid_zeros, c(73L, 72L, 13L, 11L)),
  all(sign(zero_handling$mean_corrected) == sign(zero_handling$mean_ties_as_zero)),
  all(sign(zero_handling$mean_corrected) == sign(zero_handling$mean_old_zero_rules)),
  max(abs(zero_handling$mean_change_ties)) < .00022,
  max(abs(zero_handling$mean_change_both)) < .0001
)

# Uniform duplication in US Primaries.
hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv")
raw <- read_dp_source("participant_data")
indices <- read_dp_source("index_dictionary") |> filter(dpnum == 16)
primaries <- raw |> filter(dpnum == 16)
unique_primaries <- primaries[!duplicated(primaries[setdiff(names(primaries), "X")]), ]
variants <- bind_rows(
  primaries |> mutate(scenario = "duplicates"),
  unique_primaries |> mutate(scenario = "deduplicated")
)
duplicate_scores <- map2(indices$t1var, indices$t2_t3var, \(t1var, t2var) {
  variants |>
    summarise(
      t1mean = mean(.data[[t1var]], na.rm = TRUE), t2mean = mean(.data[[t2var]], na.rm = TRUE),
      t1sd = sd(.data[[t1var]], na.rm = TRUE), t2sd = sd(.data[[t2var]], na.rm = TRUE),
      .by = c(pollgroup, scenario)
    ) |>
    mutate(
      pair_id = paste0("16:", pollgroup, "::", t1var),
      h = t1sd - t2sd, p = -signed_move(t1mean, t2mean, .5)
    )
}) |>
  list_rbind()
duplicate_checks <- duplicate_scores |>
  filter(scenario == "deduplicated") |>
  left_join(hp |> select(pair_id, homoex, polarex), by = "pair_id", relationship = "one-to-one")
stopifnot(
  nrow(duplicate_checks) == sum(hp$poll_id == 16),
  max(abs(duplicate_checks$h - duplicate_checks$homoex)) < 1e-12,
  isTRUE(all.equal(duplicate_checks$p, duplicate_checks$polarex))
)
duplicate_pairs <- duplicate_scores |>
  select(pair_id, scenario, h, p, t1mean, t2mean) |>
  pivot_wider(names_from = scenario, values_from = c(h, p, t1mean, t2mean))
stopifnot(
  max(abs(duplicate_pairs$t1mean_duplicates - duplicate_pairs$t1mean_deduplicated)) < 1e-12,
  max(abs(duplicate_pairs$t2mean_duplicates - duplicate_pairs$t2mean_deduplicated)) < 1e-12,
  isTRUE(all.equal(duplicate_pairs$p_duplicates, duplicate_pairs$p_deduplicated))
)
duplicate_scenarios <- hp |>
  left_join(
    duplicate_pairs |> select(pair_id, h_duplicates),
    by = "pair_id", relationship = "one-to-one"
  ) |>
  mutate(duplicates = if_else(poll_id == 16, h_duplicates, homoex), deduplicated = homoex) |>
  select(poll_id, pair_id, duplicates, deduplicated) |>
  pivot_longer(c(duplicates, deduplicated), names_to = "scenario", values_to = "h")

duplicate_impact <- duplicate_scenarios |>
  nest(.by = scenario) |>
  mutate(result = map(data, \(observations) {
    model <- lm(h ~ 1, data = observations)
    clubSandwich::conf_int(model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite", p_values = TRUE
    ) |>
      as_tibble() |>
      transmute(
        mean_h = beta, positive_h = mean(observations$h > movement_eps),
        p = p_val, conf_low = CI_L, conf_high = CI_U, n = nrow(observations)
      )
  })) |>
  select(-data) |>
  unnest(result)
stopifnot(
  nrow(primaries) == 434, nrow(unique_primaries) == 217,
  identical(primaries$caseid[1:217], primaries$caseid[218:434])
)
# Compare values without the export row counter or data-frame row names.
stopifnot(isTRUE(all.equal(
  unname(as.matrix(primaries[1:217, setdiff(names(primaries), "X")])),
  unname(as.matrix(primaries[218:434, setdiff(names(primaries), "X")]))
)))
stopifnot(
  all(duplicate_impact$positive_h == mean(hp$homofreq)),
  abs(duplicate_impact$mean_h[duplicate_impact$scenario == "deduplicated"] -
        mean(hp$homoex)) < 1e-12,
  all((duplicate_pairs$h_duplicates > movement_eps) ==
        (duplicate_pairs$h_deduplicated > movement_eps))
)

# The historical replication is preserved by tag, not a second working output tree.
stopifnot(system2("git", c("rev-parse", "paper-2022^{commit}"), stdout = TRUE) ==
            "497d2aeb15f9aeeed6e790a8b91b2418385a35a4")
archived_files <- c(
  "tabs/02_table_2_hom_pol.csv", "tabs/04_table_4a_toward_male.csv",
  "tabs/04_table_4b_toward_highed.csv", "tabs/04_table_4c_toward_highinc.csv",
  "tabs/04_table_4d_toward_triple.csv"
)
archived_tables <- set_names(archived_files) |>
  map(\(path) {
    read.csv(text = system2(
      "git", c("show", paste0("paper-2022:", path)), stdout = TRUE
    ))
  })

# Historical aggregation includes stale index counts and the appended Mean row.
# Apply it to corrected pair scores to isolate aggregation from score construction.
inputs <- list(
  hp = list(
    data = hp,
    file = "tabs/02_table_2_hom_pol.csv",
    outcomes = c("homoex", "homofreq", "polarex", "polarfreq")
  ),
  gender = list(
    data = filter(domination_pairs, dimension == "gender"),
    file = "tabs/04_table_4a_toward_male.csv",
    outcomes = c("ext_grp", "freqgrp_grp")
  ),
  educ = list(
    data = filter(domination_pairs, dimension == "educ"),
    file = "tabs/04_table_4b_toward_highed.csv",
    outcomes = c("ext_grp", "freqgrp_grp")
  ),
  income = list(
    data = filter(domination_pairs, dimension == "income"),
    file = "tabs/04_table_4c_toward_highinc.csv",
    outcomes = c("ext_grp", "freqgrp_grp")
  ),
  triple = list(
    data = filter(domination_pairs, dimension == "triple"),
    file = "tabs/04_table_4d_toward_triple.csv",
    outcomes = c("ext_grp", "freqgrp_grp")
  )
)
aggregation_impact <- imap(inputs, \(input, dimension) {
  metadata <- archived_tables[[input$file]] |>
    filter(!pollname %in% c("Mean", "Weighted Mean (By Indices and Groups)")) |>
    transmute(
      poll_id = as.integer(pollnum),
      ngroups = as.numeric(ngroups), nindices = as.numeric(nindices)
    )
  rows <- input$data |>
    summarise(across(all_of(input$outcomes), \(x) mean(x, na.rm = TRUE)), .by = poll_id) |>
    left_join(metadata, by = "poll_id", relationship = "one-to-one")
  stopifnot(!anyNA(rows$ngroups), !anyNA(rows$nindices))
  with_mean_row <- bind_rows(rows, rows |> summarise(across(everything(), mean)))
  old <- with_mean_row |>
    summarise(across(all_of(input$outcomes), \(x) weighted.mean(x, ngroups * nindices))) |>
    pivot_longer(everything(), names_to = "measure", values_to = "historical_aggregation")
  corrected <- input$data |>
    summarise(across(all_of(input$outcomes), \(x) mean(x, na.rm = TRUE))) |>
    pivot_longer(everything(), names_to = "measure", values_to = "actual_valid_pairs")
  left_join(old, corrected, by = "measure") |> mutate(dimension = dimension, .before = 1)
}) |>
  list_rbind() |>
  mutate(change = actual_valid_pairs - historical_aggregation)

# Verify the historical averaging formula on its archived poll rows.
archive <- archived_tables[["tabs/02_table_2_hom_pol.csv"]]
archived_measures <- c("homoex", "homofreq", "polarex", "polarfreq")
recreated <- archive |>
  filter(pollname != "Weighted Mean (By Indices and Groups)") |>
  summarise(across(all_of(archived_measures), \(x) weighted.mean(x, ngroups * nindices)))
archived_summary <- archive |>
  filter(pollname == "Weighted Mean (By Indices and Groups)") |>
  select(all_of(archived_measures))
stopifnot(max(abs(unlist(recreated) - unlist(archived_summary))) < 1e-12)


# Predictor-only comparison on the same corrected outcomes and eligible respondents.
unique_data <- raw[!duplicated(raw[setdiff(names(raw), "X")]), ] |>
  mutate(
    group_key = paste(dpnum, pollgroup, sep = ":"),
    combined_advantage = highinc == 1 & bettered == 1 & female == 0
  )
predictors <- unique_data |>
  filter(!is.na(hhincome), !is.na(combined_advantage)) |>
  summarise(
    low_income_women = mean(highinc == 0 & female == 1, na.rm = TRUE),
    any_disadvantage = mean(!combined_advantage), .by = group_key
  )
combined_pairs <- domination_pairs |>
  filter(dimension == "triple", !is.na(ext_grp)) |>
  left_join(predictors, by = "group_key", relationship = "many-to-one")
stopifnot(
  !anyNA(combined_pairs$low_income_women),
  max(abs(combined_pairs$any_disadvantage - combined_pairs$disadvantaged_share)) < 1e-12
)
predictor_impact <- combined_pairs |>
  select(poll_id, group_key, ext_grp, low_income_women, any_disadvantage) |>
  pivot_longer(c(low_income_women, any_disadvantage),
    names_to = "predictor", values_to = "share"
  ) |>
  nest(.by = predictor) |>
  mutate(result = map(data, \(observations) {
    model <- lm(ext_grp ~ share, data = observations)
    clubSandwich::coef_test(model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite"
    ) |>
      as_tibble() |>
      filter(Coef == "share") |>
      transmute(
        slope = beta, p = p_Satt,
        prediction_at_20 = unname(predict(model, data.frame(share = .2))),
        prediction_at_80 = unname(predict(model, data.frame(share = .8))),
        n_pairs = nrow(observations), n_groups = n_distinct(observations$group_key),
        n_polls = n_distinct(observations$poll_id)
      )
  })) |>
  select(-data) |>
  unnest(result)
released_parsing <- read.csv("tabs/07_parsing_domination.csv") |>
  filter(dimension == "triple", outcome == "ext_grp")
predictor_baseline <- predictor_impact |> filter(predictor == "any_disadvantage")
stopifnot(
  all(predictor_impact$n_polls == 11), all(predictor_impact$n_groups == 173),
  all(predictor_impact$n_pairs == 983),
  abs(predictor_baseline$slope - released_parsing$slope) < 1e-12,
  abs(predictor_baseline$p - released_parsing$slope_p) < 1e-10,
  abs(predictor_baseline$prediction_at_20 - released_parsing$prediction_at_20) < 1e-12,
  abs(predictor_baseline$prediction_at_80 - released_parsing$prediction_at_80) < 1e-12
)

# Stable reported conclusions, alongside the numerical comparisons above.
stopifnot(
  all(sign(missing_mean_comparison$estimate_zero) ==
        sign(missing_mean_comparison$estimate_missing)),
  all((missing_mean_comparison$p_zero < .05) == (missing_mean_comparison$p_missing < .05))
)
audit_checks <- list(
  missing_means = missing_means,
  missing_mean_impact = missing_mean_comparison,
  reference_ties = zero_handling,
  duplicate_impact = duplicate_impact,
  aggregation_impact = aggregation_impact,
  predictor_impact = predictor_impact
)

# Published-to-current comparisons and coverage of the existing claim ledger.
published_comparison <- read.csv("provenance/values.csv") |>
  filter(claim_id == "C007", version %in% c("published", "fully_corrected")) |>
  select(construct, dimension, measure, version, estimate) |>
  pivot_wider(names_from = version, values_from = estimate) |>
  mutate(
    change = fully_corrected - published,
    sign_changed = sign(fully_corrected) != sign(published) &
      abs(fully_corrected) > movement_eps & abs(published) > movement_eps,
    parity_changed = grepl("b$", measure, ignore.case = TRUE) &
      sign(fully_corrected - .5) != sign(published - .5)
  )

stopifnot(
  nrow(published_comparison) == 12,
  all(complete.cases(published_comparison[c("published", "fully_corrected")]))
)


claims <- read.csv("provenance/claims.csv")
values <- read.csv("provenance/values.csv")
artifacts <- read.csv("provenance/artifacts.csv")
checks <- read.csv("provenance/checks.csv")

claim_audit <- claims |>
  left_join(
    values |>
      summarise(
        value_rows = n(),
        versions = paste(sort(unique(version)), collapse = ","),
        .by = claim_id
      ),
    by = "claim_id"
  ) |>
  mutate(
    value_rows = coalesce(value_rows, 0L),
    versions = coalesce(versions, "none"),
    artifact_exists = artifact == "direct arithmetic" |
      artifact == "No untreated comparison or measured mechanism" |
      file.exists(artifact)
  )


stopifnot(
  all(artifacts$exists), all(checks$passed), all(claim_audit$artifact_exists),
  all(file.exists(artifacts$path)),
  all(map_chr(artifacts$path, \(path) digest::digest(path, algo = "sha256", file = TRUE)) ==
        artifacts$sha256)
)
if (sys.nframe() == 0L) {
  write.csv(published_comparison, "tabs/91_audit_comparison.csv", row.names = FALSE)
  write.csv(claim_audit, "tabs/92_full_audit.csv", row.names = FALSE)
  print(published_comparison, n = Inf)
  for (check_name in names(audit_checks)) {
    cat("\n", check_name, "\n", sep = "")
    print(as.data.frame(audit_checks[[check_name]]), row.names = FALSE, digits = 8)
  }
  cat("\nAll comparison and provenance checks passed.\n")
}
