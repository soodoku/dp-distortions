"
Deliberative Distortions
Homogenization and polarization on actual group-index pairs
"

source("scripts/00_functions.R")

dat <- load_dp_data()
dpdat <- dat$dpdat
att_indices <- dat$att_indices

hom_pol_index <- function(smdata, t1var, t2var) {
  tibble(
    group_id = as.character(smdata$pollgroup),
    group_key = smdata$group_key,
    t1 = smdata[[t1var]],
    t2 = smdata[[t2var]]
  ) |>
    summarise(
      t1mean = na_if(mean(t1, na.rm = TRUE), NaN),
      t2mean = na_if(mean(t2, na.rm = TRUE), NaN),
      t1sd = sd(t1, na.rm = TRUE),
      t2sd = sd(t2, na.rm = TRUE),
      n_t1 = sum(!is.na(t1)),
      n_t2 = sum(!is.na(t2)),
      n_complete = sum(complete.cases(t1, t2)),
      t1mean_cc = na_if(mean(t1[complete.cases(t1, t2)], na.rm = TRUE), NaN),
      t2mean_cc = na_if(mean(t2[complete.cases(t1, t2)], na.rm = TRUE), NaN),
      t1sd_cc = sd(t1[complete.cases(t1, t2)], na.rm = TRUE),
      t2sd_cc = sd(t2[complete.cases(t1, t2)], na.rm = TRUE),
      .by = c(group_id, group_key)
    ) |>
    arrange(group_key) |>
    mutate(
      polarex = -signed_move(t1mean, t2mean, .5),
      homoex = t1sd - t2sd,
      polarfreq = movement_frequency(polarex),
      homofreq = movement_frequency(homoex),
      polar_abs = abs(t2mean - .5) - abs(t1mean - .5),
      polarex_cc = -signed_move(t1mean_cc, t2mean_cc, .5),
      homoex_cc = t1sd_cc - t2sd_cc,
      polarfreq_cc = movement_frequency(polarex_cc),
      homofreq_cc = movement_frequency(homoex_cc),
      polar_abs_cc = abs(t2mean_cc - .5) - abs(t1mean_cc - .5)
    )
}

getall <- att_indices |>
  pmap(function(poll_id, poll_name, t1var, t2_t3var, dpnum, issue_id, ...) {
    hom_pol_index(dpdat[dpdat$pollid == poll_id, ], t1var, t2_t3var) |>
      mutate(
        poll_id = dpnum,
        source_poll_id = .env$poll_id,
        poll_name = poll_name,
        issue_id = issue_id,
        pair_id = paste(group_key, issue_id, sep = "::"),
        .before = 1
      )
  }) |>
  list_rbind()

poll_info <- dpdat |>
  summarise(
    pollname = first(pollname),
    ngroups = n_distinct(group_key),
    .by = dpnum
  ) |>
  left_join(
    att_indices |>
      summarise(nindices = n(), .by = dpnum),
    by = "dpnum"
  ) |>
  rename(pollnum = dpnum)

summarise_hp <- function(d, grouping = NULL) {
  d |>
    summarise(
      n_pairs = n(),
      n_h = sum(!is.na(homoex)),
      n_p = sum(!is.na(polarex)),
      homofreq = mean(homofreq, na.rm = TRUE),
      homoex = mean(homoex, na.rm = TRUE),
      polarfreq = mean(polarfreq, na.rm = TRUE),
      polarex = mean(polarex, na.rm = TRUE),
      .by = all_of(grouping)
    )
}

poll_rows <- summarise_hp(getall, "poll_id") |>
  left_join(poll_info, by = c(poll_id = "pollnum")) |>
  mutate(pollnum = poll_id) |>
  select(
    pollname, pollnum, ngroups, nindices, n_pairs, n_h, n_p,
    homofreq, homoex, polarfreq, polarex
  ) |>
  arrange(pollnum)

pair_row <- summarise_hp(getall) |>
  mutate(
    pollname = "Pair Mean (Actual Pairs)",
    pollnum = NA_integer_,
    ngroups = n_distinct(getall$group_key),
    nindices = n_distinct(getall$issue_id)
  ) |>
  select(names(poll_rows))

res <- bind_rows(poll_rows, pair_row)

dir.create("tabs", showWarnings = FALSE)
write.csv(res, "tabs/02_table_2_hom_pol.csv", row.names = FALSE)
write.csv(getall, "tabs/03_hom_pol_by_group_issue.csv", row.names = FALSE)

cor(getall[, c("polarfreq", "homofreq", "polarex", "homoex")],
  use = "pairwise.complete.obs"
) |>
  write.csv("tabs/05_corr_hom_pol.csv", row.names = FALSE)
