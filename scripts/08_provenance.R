"
Deliberative Distortions
Machine-readable claim and artifact provenance
"

source("scripts/00_functions.R")

dir.create("provenance", showWarnings = FALSE)

claims <- tribble(
  ~claim_id, ~location, ~claim, ~status, ~artifact,
  "C001", "Abstract; pp. 1205-1206; p. 1222",
  "The analysis contains 2,601 group-issue pairs.", "corrected",
  "tabs/00_analysis_inventory.csv",
  "C002", "Abstract; pp. 1216-1218; pp. 1222-1223",
  "The data show faint opposition to domination.", "rewrite",
  "tabs/02_table_2.csv",
  "C003", "Table 1 and p. 1215",
  "Participant, group, and policy-index inventory.", "corrected",
  "tabs/00_poll_inventory.csv",
  "C004", "Footnote 12, p. 1210",
  "Correlations among homogenization, polarization, and domination.", "sample_choice",
  "tabs/05_corr_hpd.csv",
  "C005", "p. 1216",
  "Six of ten Table 2 estimates are statistically significant.", "corrected",
  "tabs/02_table_2.csv",
  "C006", "p. 1216",
  "Two of twenty participants moving .1 changes the mean by .10.", "corrected",
  "direct arithmetic",
  "C007", "Table 2, p. 1218",
  "Main homogenization, polarization, and domination estimates.", "corrected",
  "tabs/02_table_2.csv",
  "C008", "Figure 3, p. 1217; Appendix B",
  "Distributions and subgroup comparisons use common constructs.", "corrected",
  "figs/figure_manifest.csv",
  "C009", "Table 3, p. 1220",
  "Group and subgroup movement estimates.", "corrected",
  "tabs/03_table_3.csv",
  "C010", "pp. 1219-1220 and footnote 22",
  "Domination varies with the disadvantaged share of the group.", "corrected",
  "tabs/07_parsing_domination.csv",
  "C011", "pp. 1220-1221",
  "Net and gross attitude change are .092 and .203.", "weighting_choice",
  "tabs/05_attitude_change_weighting.csv",
  "C012", "Footnote 20, p. 1216",
  "Huber-White standard errors are clustered by policy index.", "corrected",
  "scripts/03_se.R",
  "C013", "Conclusion, pp. 1222-1223",
  "The paper interprets the pattern as compatible with weighing the merits.",
  "interpretation_review", "AUDIT.md"
)
write.csv(claims, "provenance/claims.csv", row.names = FALSE)

paper_path <- paste0(
  "deliberative-distortions-homogenization-polarization-and-domination-",
  "in-small-group-discussions.pdf"
)
upstream <- dp_source_manifest()
upstream <- upstream[match(c("participant_data", "index_dictionary"), upstream$source), ]
source_paths <- c(
  paper_path, dp_source_path("participant_data"), dp_source_path("index_dictionary"), "renv.lock"
)
sources <- tibble(
  source_id = c("paper_vor", "participant_data", "index_dictionary", "package_lock"),
  repository = c("soodoku/dp-distortions", upstream$repository, "soodoku/dp-distortions"),
  revision = c(NA_character_, upstream$revision, NA_character_),
  path = c(paper_path, upstream$path, "renv.lock"),
  official_url = c("https://doi.org/10.1017/S0007123421000168", NA, NA, NA),
  editable = c(FALSE, FALSE, FALSE, TRUE),
  sha256 = map_chr(source_paths, \(p) digest::digest(p, algo = "sha256", file = TRUE))
)
write.csv(sources, "provenance/sources.csv", row.names = FALSE)

published_table2 <- tribble(
  ~construct, ~dimension, ~measure, ~estimate,
  "Homogenization", NA_character_, "H", .013,
  "Homogenization", NA_character_, "Hb", .595,
  "Directional polarization", NA_character_, "P", -.022,
  "Directional polarization", NA_character_, "Pb", .454,
  "Domination", "Gender", "D", .008,
  "Domination", "Gender", "Db", .464,
  "Domination", "Education", "D", -.013,
  "Domination", "Education", "Db", .447,
  "Domination", "Income", "D", 0,
  "Domination", "Income", "Db", .485,
  "Domination", "Gender, education, and income", "D", -.015,
  "Domination", "Gender, education, and income", "Db", .466
)

corrected_table2 <- read.csv("tabs/02_table_2.csv") |>
  select(
    construct, dimension, measure, estimate, se, df, p,
    conf_low, conf_high, n_pairs, n_groups, n_issues, n_polls,
    p_holm_12, p_bh_12, p_wild_cluster
  )

values_table2 <- bind_rows(
  published_table2 |>
    mutate(
      claim_id = "C007", version = "published",
      estimand = "Published Table 2 construction",
      weighting = "Stale poll-level numindices weights",
      sample_rule = "Published code conventions"
    ),
  corrected_table2 |>
    mutate(
      claim_id = "C007", version = "fully_corrected",
      estimand = "Mean over actual valid group-index pairs",
      weighting = "One unit per valid group-index pair",
      sample_rule = "Exact-record deduplication; undefined reference directions excluded"
    )
)

inventory_values <- read.csv("tabs/00_analysis_inventory.csv") |>
  transmute(
    claim_id = "C003", version = "fully_corrected",
    construct = "Analysis inventory", dimension = NA_character_,
    measure = quantity, estimate = value,
    estimand = definition,
    weighting = NA_character_, sample_rule = NA_character_
  )

pair_count_value <- inventory_values |>
  filter(measure == "possible_group_index_pairs") |>
  mutate(claim_id = "C001")

correlation_values <- read.csv("tabs/05_corr_hpd.csv") |>
  transmute(
    claim_id = "C004", version = "pairwise_sample",
    construct = "Pairwise correlation", dimension = x,
    measure = y, estimate = correlation, n_pairs = n,
    estimand = "Pairwise-complete correlation over common group-index pairs",
    weighting = "One unit per valid group-index pair",
    sample_rule = "Outcome-specific pairwise complete cases"
  )

significance_value <- tibble(
  claim_id = "C005", version = "fully_corrected",
  construct = "Table 2 inference", dimension = NA_character_,
  measure = "p_below_.05", estimate = sum(corrected_table2$p < .05),
  estimand = "Count of the 12 primary poll-clustered CR2 p-values below .05",
  weighting = NA_character_, sample_rule = "Unadjusted p-values"
)

arithmetic_value <- tibble(
  claim_id = "C006", version = "fully_corrected",
  construct = "Numerical example", dimension = NA_character_,
  measure = "mean_change", estimate = 2 * .1 / 20,
  estimand = "Two of twenty participants each moving .1",
  weighting = "Equal participant weights", sample_rule = NA_character_
)

table3_values <- read.csv("tabs/03_table_3.csv") |>
  transmute(
    claim_id = "C009", version = "fully_corrected",
    construct = "Table 3", dimension, measure, estimate, se, df, p,
    n_pairs,
    estimand = "Mean over actual valid group-index pairs",
    weighting = "One unit per valid group-index pair",
    sample_rule = "Exact-record deduplication; undefined directions excluded"
  )

parsing_values <- read.csv("tabs/07_parsing_domination.csv") |>
  transmute(
    claim_id = "C010", version = "fully_corrected",
    construct = "Parsing domination", dimension, measure = outcome,
    estimate = slope, se = slope_se, df = slope_df, p = slope_p,
    n_pairs,
    estimand = "Linear association with the group disadvantaged share",
    weighting = "One unit per valid group-index pair",
    sample_rule = "Predictor share and outcome use the same eligible participants"
  )

attitude_change_values <- read.csv("tabs/05_attitude_change_weighting.csv") |>
  pivot_longer(c(net_change, gross_change), names_to = "measure", values_to = "estimate") |>
  transmute(
    claim_id = "C011", version = "weighting_comparison",
    construct = "Attitude change", dimension = weighting,
    measure, estimate,
    estimand = "Average net or gross within-person change under the stated weighting",
    weighting,
    sample_rule = "Within-person complete pre-post responses"
  )

inference_values <- corrected_table2 |>
  mutate(
    claim_id = "C012", version = "fully_corrected",
    estimand = "Poll-clustered CR2 inference for actual-pair means",
    weighting = "One unit per valid group-index pair",
    sample_rule = "Poll is the primary independent cluster"
  )

opposition_values <- corrected_table2 |>
  filter(construct == "Domination") |>
  mutate(
    claim_id = "C002", version = "fully_corrected",
    estimand = "Equation 3 movement toward the advantaged subgroup",
    weighting = "One unit per valid group-index pair",
    sample_rule = "Undefined reference directions excluded"
  )

write.csv(
  bind_rows(
    values_table2, inventory_values, pair_count_value,
    correlation_values, significance_value, arithmetic_value,
    table3_values, parsing_values, attitude_change_values,
    inference_values,
    opposition_values
  ),
  "provenance/values.csv",
  row.names = FALSE
)

artifact_spec <- tribble(
  ~path, ~producer,
  "tabs/00_analysis_inventory.csv", "scripts/00_inventory.R",
  "tabs/00_poll_inventory.csv", "scripts/00_inventory.R",
  "tabs/03_hom_pol_by_group_issue.csv", "scripts/01_hom_pol.R",
  "tabs/03_dom_gender_by_group_issue.csv", "scripts/02_domination.R",
  "tabs/03_dom_educ_by_group_issue.csv", "scripts/02_domination.R",
  "tabs/03_dom_income_by_group_issue.csv", "scripts/02_domination.R",
  "tabs/03_dom_triple_by_group_issue.csv", "scripts/02_domination.R",
  "tabs/02_table_2.csv", "scripts/03_se.R",
  "tabs/03_table_3.csv", "scripts/03_se.R",
  "tabs/05_corr_hpd.csv", "scripts/04_corr_parsing.R",
  "tabs/07_parsing_domination.csv", "scripts/04_corr_parsing.R",
  "tabs/05_attitude_change.csv", "scripts/05_attitude_change.R",
  "tabs/05_attitude_change_weighting.csv", "scripts/05_attitude_change.R",
  "tabs/09_paired_response_sensitivity.csv", "scripts/09_sensitivity.R",
  "tabs/09_frequency_comparison.csv", "scripts/09_sensitivity.R",
  "figs/figure_manifest.csv", "scripts/06_figs.R",
  "tabs/99_validation.csv", "scripts/07_validate.R"
)

hash_file <- function(path) {
  digest::digest(path, algo = "sha256", file = TRUE)
}

artifacts <- artifact_spec |>
  mutate(
    exists = file.exists(path),
    sha256 = if_else(exists,
      map_chr(path, hash_file),
      NA_character_
    )
  )
write.csv(artifacts, "provenance/artifacts.csv", row.names = FALSE)
write.csv(read.csv("tabs/99_validation.csv"),
  "provenance/checks.csv",
  row.names = FALSE
)

stopifnot(all(artifacts$exists), all(read.csv("provenance/checks.csv")$passed))
