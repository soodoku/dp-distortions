"
Deliberative Distortions
Permanent data and result gates
"

source("scripts/00_functions.R")

checks <- new.env(parent = emptyenv())
checks$items <- list()
record_check <- function(check, value, expected, passed) {
  checks$items[[length(checks$items) + 1]] <- tibble(
    check = check,
    value = as.character(value),
    expected = as.character(expected),
    passed = isTRUE(passed)
  )
}

dat <- load_dp_data()
dpdat <- dat$dpdat
att_indices <- dat$att_indices
hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv")

record_check("raw participant rows", dat$raw_n, 6084, dat$raw_n == 6084)
record_check(
  "exact duplicate rows", nrow(dat$duplicate_rows), 217,
  nrow(dat$duplicate_rows) == 217
)
record_check(
  "analysis participants", dat$analysis_n, 5867,
  dat$analysis_n == 5867
)
record_check(
  "unique participant keys", anyDuplicated(dpdat$participant_id), 0,
  !anyDuplicated(dpdat$participant_id)
)
record_check(
  "attitude indices", nrow(att_indices), 129,
  nrow(att_indices) == 129 && !anyDuplicated(att_indices$issue_id)
)
record_check(
  "canonical pair rows", nrow(hp), 2480,
  nrow(hp) == 2480 && !anyDuplicated(hp$pair_id)
)

expected_poll_pairs <- c(
  64, 135, 60, 60, 48, 100, 126, 96, 144, 204, 50,
  32, 216, 135, 90, 48, 104, 330, 84, 270, 84
)
observed_poll_pairs <- as.integer(table(factor(hp$poll_id, levels = 1:21)))
record_check(
  "pair rows by poll", paste(observed_poll_pairs, collapse = ","),
  paste(expected_poll_pairs, collapse = ","),
  identical(observed_poll_pairs, as.integer(expected_poll_pairs))
)
record_check(
  "valid H pairs", sum(!is.na(hp$homoex)), 2480,
  sum(!is.na(hp$homoex)) == 2480
)
record_check(
  "valid P pairs", sum(!is.na(hp$polarex)), 2431,
  sum(!is.na(hp$polarex)) == 2431
)

raw <- read_dp_source("participant_data") |>
  mutate(group_key = paste(dpnum, pollgroup, sep = ":"))
attitude_columns <- unique(c(att_indices$t1var, att_indices$t2_t3var))
raw_means <- raw |>
  summarise(across(all_of(attitude_columns), \(x) mean(x, na.rm = TRUE)),
    .by = group_key
  )
dedup_means <- dpdat |>
  summarise(across(all_of(attitude_columns), \(x) mean(x, na.rm = TRUE)),
    .by = group_key
  )
mean_difference <- raw_means |>
  inner_join(dedup_means, by = "group_key", suffix = c("_raw", "_dedup")) |>
  select(-group_key) |>
  as.matrix()
half <- ncol(mean_difference) / 2
raw_matrix <- mean_difference[, seq_len(half)]
dedup_matrix <- mean_difference[, half + seq_len(half)]
max_mean_change <- max(abs(raw_matrix - dedup_matrix), na.rm = TRUE)
record_check(
  "deduplication preserves group means", max_mean_change, "<=1e-15",
  max_mean_change <= 1e-15
)

expected_domination <- tribble(
  ~dimension, ~rows, ~other_missing, ~reference_undefined, ~valid, ~genuine_zero,
  "educ", 2437, 1, 51, 2385, 72,
  "gender", 2476, 0, 40, 2436, 73,
  "income", 1162, 1, 17, 1144, 13,
  "triple", 1000, 6, 11, 983, 11
)

headline_expected <- c(
  H = 0.012849354,
  Hb = 0.585887097,
  P = -0.022210726,
  Pb = 0.439736734,
  gender_D = 0.001754300,
  gender_Db = 0.471264368,
  educ_D = 0.010042516,
  educ_Db = 0.523270440,
  income_D = 0.001506264,
  income_Db = 0.505244755,
  triple_D = 0.012851850,
  triple_Db = 0.518819939
)
headline_observed <- c(
  H = mean(hp$homoex, na.rm = TRUE),
  Hb = mean(hp$homofreq, na.rm = TRUE),
  P = mean(hp$polarex, na.rm = TRUE),
  Pb = mean(hp$polarfreq, na.rm = TRUE)
)

hp_keys <- hp[c("poll_id", "group_key", "issue_id")]
for (i in seq_len(nrow(expected_domination))) {
  expected <- expected_domination[i, ]
  d <- read.csv(sprintf(
    "tabs/03_dom_%s_by_group_issue.csv",
    expected$dimension
  ))
  other_missing <- sum(is.na(d$ext_grp)) - sum(d$reference_tie, na.rm = TRUE)
  valid <- sum(!is.na(d$ext_grp))
  genuine_zero <- sum(d$no_group_movement & !d$reference_tie, na.rm = TRUE)
  observed <- c(
    nrow(d), other_missing, sum(d$reference_tie, na.rm = TRUE),
    valid, genuine_zero
  )
  target <- unlist(expected[c(
    "rows", "other_missing", "reference_undefined",
    "valid", "genuine_zero"
  )], use.names = FALSE)
  record_check(
    paste(expected$dimension, "domination accounting"),
    paste(observed, collapse = ","), paste(target, collapse = ","),
    identical(as.numeric(observed), as.numeric(target))
  )
  record_check(
    paste(expected$dimension, "Db missingness and definition"),
    sum(is.na(d$freqgrp_grp)), sum(is.na(d$ext_grp)),
    identical(is.na(d$freqgrp_grp), is.na(d$ext_grp)) &&
      all(d$freqgrp_grp[!is.na(d$ext_grp)] ==
            (d$ext_grp[!is.na(d$ext_grp)] > movement_eps))
  )
  key_match <- d[c("poll_id", "group_key", "issue_id")] |>
    anti_join(hp_keys, by = c("poll_id", "group_key", "issue_id"))
  record_check(
    paste(expected$dimension, "keys belong to canonical pairs"),
    nrow(key_match), 0, nrow(key_match) == 0
  )
  headline_observed[paste0(expected$dimension, "_D")] <-
    mean(d$ext_grp, na.rm = TRUE)
  headline_observed[paste0(expected$dimension, "_Db")] <-
    mean(d$freqgrp_grp, na.rm = TRUE)
}

headline_difference <- headline_observed[names(headline_expected)] - headline_expected
headline_delta <- max(abs(headline_difference))
record_check(
  "frozen headline estimates", headline_delta, "<=5e-10",
  headline_delta <= 5e-10
)

table2 <- read.csv("tabs/02_table_2.csv")
table3 <- read.csv("tabs/03_table_3.csv")
attitude_change <- read.csv("tabs/05_attitude_change.csv")
record_check("corrected Table 2 rows", nrow(table2), 12, nrow(table2) == 12)
record_check("corrected Table 3 rows", nrow(table3), 24, nrow(table3) == 24)
record_check(
  "Table 2 primary inference is complete",
  sum(complete.cases(table2[c(
    "estimate", "se", "df", "p",
    "conf_low", "conf_high"
  )])),
  12,
  all(complete.cases(table2[c(
    "estimate", "se", "df", "p",
    "conf_low", "conf_high"
  )]))
)
record_check(
  "attitude-change estimates",
  paste(round(attitude_change$estimate, 9), collapse = ","),
  "0.089414382,0.202664408",
  max(abs(attitude_change$estimate - c(0.089414382, 0.202664408))) <= 5e-10
)

analytical_scripts <- c(
  "scripts/01_hom_pol.R", "scripts/02_domination.R",
  "scripts/03_se.R", "scripts/04_corr_parsing.R"
)
stale_weight_reads <- analytical_scripts |>
  map_lgl(\(path) {
    any(grepl(
      "numindices", readLines(path, warn = FALSE),
      fixed = TRUE
    ))
  })
record_check(
  "no analytical script reads stale numindices", sum(stale_weight_reads),
  0, !any(stale_weight_reads)
)

validation <- list_rbind(checks$items)
write.csv(validation, "tabs/99_validation.csv", row.names = FALSE)

failed <- validation |>
  filter(!passed)
if (nrow(failed) > 0) {
  print(failed)
  stop(sprintf("%d validation gate(s) failed", nrow(failed)))
}

message(sprintf("All %d validation gates passed.", nrow(validation)))
