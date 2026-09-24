"
Deliberative Distortions
Analysis inventory and duplicate audit
"

source("scripts/00_functions.R")

dat <- load_dp_data()
dpdat <- dat$dpdat
att_indices <- dat$att_indices

poll_inventory <- dpdat |>
  summarise(
    participants = n(),
    groups = n_distinct(group_key),
    .by = c(dpnum, pollname)
  ) |>
  left_join(
    att_indices |>
      summarise(indices = n(), .by = dpnum),
    by = "dpnum"
  ) |>
  mutate(possible_group_index_pairs = groups * indices) |>
  arrange(dpnum)

inventory <- tribble(
  ~quantity, ~value, ~definition,
  "raw_rows", dat$raw_n, "Rows in upstream historical polardata",
  "exact_duplicate_rows", nrow(dat$duplicate_rows),
  "Rows identical on every column except the import row number X",
  "analysis_participants", dat$analysis_n,
  "Distinct participants after exact-record deduplication",
  "polls", n_distinct(dpdat$dpnum), "Deliberative polls in the analysis data",
  "groups", n_distinct(dpdat$group_key), "Small groups across all polls",
  "indices", nrow(att_indices), "Rows in the validated attitude-index dictionary",
  "possible_group_index_pairs", sum(poll_inventory$possible_group_index_pairs),
  "Groups multiplied by defined indices within each poll"
)

duplicate_audit <- dat$duplicate_rows |>
  summarise(
    duplicate_rows = n(),
    duplicate_case_ids = n_distinct(caseid),
    .by = c(dpnum, pollname)
  )

dir.create("tabs", showWarnings = FALSE)
write.csv(inventory, "tabs/00_analysis_inventory.csv", row.names = FALSE)
write.csv(poll_inventory, "tabs/00_poll_inventory.csv", row.names = FALSE)
write.csv(duplicate_audit, "tabs/00_duplicate_audit.csv", row.names = FALSE)
