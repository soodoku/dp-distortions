"
Deliberative Distortions
Domination on actual group-index pairs
"

source("scripts/00_functions.R")

dat <- load_dp_data()
dpdat <- dat$dpdat |>
  mutate(
    triple_adv = highinc == 1 & bettered == 1 & female == 0
  )
att_indices <- dat$att_indices

dims <- list(
  educ = list(
    keep = \(d) !is.na(d$bettered),
    adv = \(d) d$bettered == 1,
    table = "04_table_4b", adv_label = "highed", dis_label = "lowed"
  ),
  gender = list(
    keep = \(d) !is.na(d$female),
    adv = \(d) d$female == 0,
    table = "04_table_4a", adv_label = "male", dis_label = "female"
  ),
  income = list(
    keep = \(d) !is.na(d$hhincome) & !is.na(d$highinc),
    adv = \(d) d$highinc == 1,
    table = "04_table_4c", adv_label = "highinc", dis_label = "lowinc"
  ),
  triple = list(
    keep = \(d) !is.na(d$hhincome) & !is.na(d$triple_adv),
    adv = \(d) d$triple_adv,
    table = "04_table_4d", adv_label = "triple", dis_label = "triple_disadv"
  )
)

poll_table <- function(pairs, poll_info, ext_dis, ext_grp) {
  poll_rows <- pairs |>
    summarise(
      n_pairs = n(),
      n_dis = sum(!is.na(.data[[ext_dis]])),
      n_group = sum(!is.na(.data[[ext_grp]])),
      freqdis = mean(movement_frequency(.data[[ext_dis]]), na.rm = TRUE),
      extdis = mean(.data[[ext_dis]], na.rm = TRUE),
      freqgrp = mean(movement_frequency(.data[[ext_grp]]), na.rm = TRUE),
      extgrp = mean(.data[[ext_grp]], na.rm = TRUE),
      .by = poll_id
    ) |>
    left_join(poll_info, by = "poll_id") |>
    mutate(pollnum = poll_id) |>
    select(
      pollname, pollnum, ngroups, nindices, n_pairs, n_dis, n_group,
      freqdis, extdis, freqgrp, extgrp
    ) |>
    arrange(pollnum)

  pair_row <- pairs |>
    summarise(
      n_pairs = n(),
      n_dis = sum(!is.na(.data[[ext_dis]])),
      n_group = sum(!is.na(.data[[ext_grp]])),
      freqdis = mean(movement_frequency(.data[[ext_dis]]), na.rm = TRUE),
      extdis = mean(.data[[ext_dis]], na.rm = TRUE),
      freqgrp = mean(movement_frequency(.data[[ext_grp]]), na.rm = TRUE),
      extgrp = mean(.data[[ext_grp]], na.rm = TRUE)
    ) |>
    mutate(
      pollname = "Pair Mean (Actual Pairs)",
      pollnum = NA_integer_,
      ngroups = n_distinct(pairs$group_key),
      nindices = n_distinct(pairs$issue_id)
    ) |>
    select(names(poll_rows))

  bind_rows(poll_rows, pair_row)
}

dir.create("tabs", showWarnings = FALSE)

for (dim_name in names(dims)) {
  cfg <- dims[[dim_name]]
  data <- dpdat[cfg$keep(dpdat), , drop = FALSE]

  pairs <- att_indices |>
    filter(poll_id %in% unique(data$pollid)) |>
    pmap(function(poll_id, poll_name, t1var, t2_t3var, dpnum, issue_id, ...) {
      smdata <- data[data$pollid == poll_id, , drop = FALSE]
      pair_data <- dom_pairs_index(smdata, t1var, t2_t3var, cfg$adv(smdata))
      if (is.null(pair_data)) {
        return(NULL)
      }
      paired_data <- smdata[complete.cases(smdata[c(t1var, t2_t3var)]), ]
      paired_means <- dom_pairs_index(paired_data, t1var, t2_t3var, cfg$adv(paired_data))
      if (!is.null(paired_means)) {
        paired_means <- paired_means |>
          rename_with(\(name) paste0(name, "_paired"), -group_id)
      } else {
        paired_means <- pair_data[FALSE, ] |>
          rename_with(\(name) paste0(name, "_paired"), -group_id)
      }
      pair_data |>
        left_join(paired_means, by = "group_id", relationship = "one-to-one") |>
        mutate(
          poll_id = dpnum,
          source_poll_id = .env$poll_id,
          poll_name = poll_name,
          issue_id = issue_id,
          group_key = paste(dpnum, group_id, sep = ":"),
          pair_id = paste(group_key, issue_id, sep = "::"),
          dimension = dim_name,
          .before = 1
        )
    }) |>
    list_rbind()

  stopifnot(!anyDuplicated(pairs$pair_id))

  poll_info <- data |>
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
    rename(poll_id = dpnum)

  res_adv <- poll_table(pairs, poll_info, "ext_dis", "ext_grp")
  res_dis <- poll_table(pairs, poll_info, "ext_adv_mir", "ext_grp_mir")

  write.csv(res_adv,
    sprintf("tabs/%s_toward_%s.csv", cfg$table, cfg$adv_label),
    row.names = FALSE
  )
  write.csv(res_dis,
    sprintf("tabs/%s_toward_%s.csv", cfg$table, cfg$dis_label),
    row.names = FALSE
  )

  pairs |>
    mutate(
      freqgrp_grp = movement_frequency(ext_grp),
      freqdis_grp = movement_frequency(ext_dis),
      freqgrp_mir = movement_frequency(ext_grp_mir),
      freqadv_mir = movement_frequency(ext_adv_mir),
      freqadv_grp = movement_frequency(ext_adv)
    ) |>
    write.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", dim_name),
      row.names = FALSE
    )
}
