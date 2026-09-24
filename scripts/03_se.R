"
Deliberative Distortions
Direct pair means with poll-clustered CR2 inference
"

source("scripts/00_functions.R")
suppressPackageStartupMessages({
  library(sandwich)
  library(clubSandwich)
})

if (Sys.getenv("R_USER_CONFIG_DIR") == "") {
  Sys.setenv(R_USER_CONFIG_DIR = file.path(tempdir(), "r-config"))
}

infer_mean <- function(data, outcome, null = 0) {
  d <- data |>
    transmute(
      y = as.numeric(.data[[outcome]]) - null,
      group_key, issue_id, poll_id
    ) |>
    filter(complete.cases(y, group_key, issue_id, poll_id))

  stopifnot(
    nrow(d) > 1,
    n_distinct(d$group_key) > 1,
    n_distinct(d$issue_id) > 1,
    n_distinct(d$poll_id) > 1
  )

  fit <- lm(y ~ 1, data = d)
  vcov_two_way <- vcovCL(
    fit,
    cluster = d[c("group_key", "issue_id")],
    type = "HC1",
    cadjust = TRUE,
    multi0 = TRUE,
    fix = FALSE
  )
  two_way_variance <- vcov_two_way[1, 1]
  se_two_way <- if (two_way_variance >= 0) sqrt(two_way_variance) else NA_real_
  df_two_way <- min(n_distinct(d$group_key), n_distinct(d$issue_id)) - 1
  estimate <- unname(coef(fit)[1]) + null
  statistic_two_way <- (estimate - null) / se_two_way
  p_two_way <- 2 * pt(abs(statistic_two_way),
    df = df_two_way, lower.tail = FALSE
  )

  poll_test <- conf_int(
    fit,
    vcov = "CR2",
    cluster = d$poll_id,
    test = "Satterthwaite",
    p_values = TRUE
  )

  loo <- unique(d$poll_id) |>
    map_dbl(\(p) mean(d$y[d$poll_id != p]) + null)

  tibble(
    estimate = estimate,
    null = null,
    se = poll_test$SE,
    df = poll_test$df,
    p = poll_test$p_val,
    conf_low = poll_test$CI_L + null,
    conf_high = poll_test$CI_U + null,
    se_two_way = se_two_way,
    df_two_way = df_two_way,
    p_two_way = p_two_way,
    two_way_variance_nonnegative = two_way_variance >= 0,
    n_pairs = nrow(d),
    n_groups = n_distinct(d$group_key),
    n_issues = n_distinct(d$issue_id),
    n_polls = n_distinct(d$poll_id),
    mean_absolute = if (null == 0) mean(abs(d$y)) else NA_real_,
    proportion_abs_gt_10 = if (null == 0) mean(abs(d$y) > .1) else NA_real_,
    proportion_abs_gt_20 = if (null == 0) mean(abs(d$y) > .2) else NA_real_,
    leave_one_poll_min = min(loo),
    leave_one_poll_max = max(loo)
  )
}

wild_cluster_p <- function(data, outcome, null = 0, seed = 20260818) {
  d <- data |>
    transmute(y = as.numeric(.data[[outcome]]) - null, poll_id) |>
    filter(complete.cases(y, poll_id))

  set.seed(seed)
  dqrng::dqset.seed(seed)
  fit <- fixest::feols(y ~ 1, data = d)
  bootstrap <- suppressMessages(suppressWarnings(
    fwildclusterboot::boottest(
      fit,
      param = "(Intercept)",
      B = 99999,
      clustid = "poll_id",
      type = if (n_distinct(d$poll_id) < 12) "webb" else "rademacher",
      bootstrap_type = "fnw11",
      impose_null = TRUE,
      p_val_type = "two-tailed",
      engine = "R",
      nthreads = 1,
      conf_int = FALSE
    )
  ))
  bootstrap$p_val
}

hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv")

hp_specs <- tribble(
  ~construct, ~measure, ~outcome, ~null,
  "Homogenization", "H", "homoex", 0,
  "Homogenization", "Hb", "homofreq", .5,
  "Directional polarization", "P", "polarex", 0,
  "Directional polarization", "Pb", "polarfreq", .5
)

table2_hp <- hp_specs |>
  pmap(\(construct, measure, outcome, null) {
    infer_mean(hp, outcome, null) |>
      mutate(
        construct = construct,
        dimension = NA_character_,
        measure = measure,
        outcome = outcome,
        .before = 1
      )
  }) |>
  list_rbind()

dimensions <- c("gender", "educ", "income", "triple")
dimension_labels <- c(
  gender = "Gender",
  educ = "Education",
  income = "Income",
  triple = "Gender, education, and income"
)

dom_pairs <- dimensions |>
  set_names() |>
  map(\(d) read.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", d)))

table2_dom <- dimensions |>
  map(\(dimension) {
    map2(c("D", "Db"), c("ext_grp", "freqgrp_grp"), \(measure, outcome) {
      infer_mean(
        dom_pairs[[dimension]], outcome,
        if (measure == "Db") .5 else 0
      ) |>
        mutate(
          construct = "Domination",
          dimension = dimension_labels[[dimension]],
          measure = measure,
          outcome = outcome,
          .before = 1
        )
    }) |>
      list_rbind()
  }) |>
  list_rbind()

table2 <- bind_rows(table2_hp, table2_dom) |>
  mutate(
    p_wild_cluster = c(
      pmap_dbl(hp_specs, \(construct, measure, outcome, null) {
        wild_cluster_p(
          hp, outcome, null,
          20260818 + match(measure, hp_specs$measure)
        )
      }),
      dimensions |>
        imap(\(dimension, i) {
          map2_dbl(
            c("ext_grp", "freqgrp_grp"), c(0, .5),
            \(outcome, null) {
              wild_cluster_p(
                dom_pairs[[dimension]], outcome, null,
                20260818 + 2 * i + (null > 0)
              )
            }
          )
        }) |>
        unlist(use.names = FALSE)
    ),
    p_holm_12 = p.adjust(p, method = "holm"),
    p_bh_12 = p.adjust(p, method = "BH"),
    p_bonferroni_12 = p.adjust(p, method = "bonferroni"),
    p_wild_holm_12 = p.adjust(p_wild_cluster, method = "holm"),
    p_wild_bh_12 = p.adjust(p_wild_cluster, method = "BH")
  )

table3_specs <- tribble(
  ~measure, ~outcome, ~null,
  "D", "ext_grp", 0,
  "dM", "ext_dis", 0,
  "aM", "ext_adv", 0,
  "Db", "freqgrp_grp", .5,
  "dMb", "freqdis_grp", .5,
  "aMb", "freqadv_grp", .5
)

table3 <- dimensions |>
  map(\(dimension) {
    table3_specs |>
      pmap(\(measure, outcome, null) {
        infer_mean(dom_pairs[[dimension]], outcome, null) |>
          mutate(
            dimension = dimension_labels[[dimension]],
            measure = measure,
            outcome = outcome,
            .before = 1
          )
      }) |>
      list_rbind()
  }) |>
  list_rbind() |>
  mutate(
    p_holm_24 = p.adjust(p, method = "holm"),
    p_bh_24 = p.adjust(p, method = "BH"),
    p_bonferroni_24 = p.adjust(p, method = "bonferroni")
  )

dir.create("tabs", showWarnings = FALSE)
write.csv(table2, "tabs/02_table_2.csv", row.names = FALSE)
write.csv(table3, "tabs/03_table_3.csv", row.names = FALSE)
