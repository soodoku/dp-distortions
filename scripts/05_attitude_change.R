"
Deliberative Distortions
Net and gross attitude change on actual group-index pairs
"

source("scripts/00_functions.R")

dat <- load_dp_data()
dpdat <- dat$dpdat
att_indices <- dat$att_indices

attitude_change_index <- function(smdata, t1var, t2var) {
  tibble(
    group_id = as.character(smdata$pollgroup),
    group_key = smdata$group_key,
    t1 = smdata[[t1var]],
    t2 = smdata[[t2var]]
  ) |>
    mutate(change = t2 - t1) |>
    summarise(
      net_change = abs(na_if(mean(change, na.rm = TRUE), NaN)),
      gross_change = na_if(mean(abs(change), na.rm = TRUE), NaN),
      n_complete = sum(!is.na(change)),
      .by = c(group_id, group_key)
    )
}

pairs <- att_indices |>
  pmap(function(poll_id, poll_name, t1var, t2_t3var, dpnum, issue_id, ...) {
    attitude_change_index(dpdat[dpdat$pollid == poll_id, ], t1var, t2_t3var) |>
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

summary <- tribble(
  ~measure, ~estimate, ~n_pairs,
  "Mean absolute net change", mean(pairs$net_change, na.rm = TRUE),
  sum(!is.na(pairs$net_change)),
  "Mean gross change", mean(pairs$gross_change, na.rm = TRUE),
  sum(!is.na(pairs$gross_change))
)

write.csv(pairs, "tabs/05_attitude_change_by_group_issue.csv", row.names = FALSE)
write.csv(summary, "tabs/05_attitude_change.csv", row.names = FALSE)

weighting_comparison <- bind_rows(
  pairs |>
    summarise(across(c(net_change, gross_change), \(x) mean(x, na.rm = TRUE))) |>
    mutate(weighting = "Equal group-issue pairs"),
  pairs |>
    summarise(across(c(net_change, gross_change), \(x) mean(x, na.rm = TRUE)),
      .by = group_key
    ) |>
    summarise(across(c(net_change, gross_change), \(x) mean(x, na.rm = TRUE))) |>
    mutate(weighting = "Equal groups (paper footnote 24)"),
  pairs |>
    summarise(across(c(net_change, gross_change), \(x) mean(x, na.rm = TRUE)),
      .by = poll_id
    ) |>
    summarise(across(c(net_change, gross_change), \(x) mean(x, na.rm = TRUE))) |>
    mutate(weighting = "Equal polls")
) |>
  select(weighting, net_change, gross_change)
write.csv(weighting_comparison, "tabs/05_attitude_change_weighting.csv", row.names = FALSE)
