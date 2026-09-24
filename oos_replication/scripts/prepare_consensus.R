raw_consensus_1 <- haven::read_sav(oos_source_path("consensus1.sav"))
raw_consensus_2 <- haven::read_sav(oos_source_path("consensus2.sav"))
stopifnot(
  nrow(raw_consensus_1) == 116L, !anyDuplicated(raw_consensus_1$id),
  n_distinct(raw_consensus_1$group) == 28L,
  nrow(raw_consensus_2) == 136L, n_distinct(raw_consensus_2$group) == 41L
)
consensus_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id %in% c("consensus_1", "consensus_2"))
consensus_1 <- raw_consensus_1 |>
  transmute(
    event_id = "consensus_1", participant_id = as.character(id), group_id = as.character(group),
    gender = if_else(gender %in% 1:2, gender == 1, NA),
    across(all_of(c("Att_1_pre", "Att_1_post", "Att_2_pre", "Att_2_post")), as.numeric)
  ) |>
  pivot_longer(starts_with("Att_"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(endsWith(variable, "_post"), "t2", "t1"),
    pre_variable = sub("_post$", "_pre", variable)
  )
consensus_2 <- raw_consensus_2 |>
  transmute(
    event_id = "consensus_2", participant_id = paste(group, ppnr, sep = ":"), group_id = group,
    gender = if_else(gender %in% 1:2, gender == 2, NA),
    across(all_of(c(
      "generalattitude_time1", "generalattitude_time2",
      "affirmativeaction_time1", "affirmativeaction_time2"
    )), as.numeric)
  ) |>
  pivot_longer(ends_with(c("time1", "time2")), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(endsWith(variable, "time2"), "t2", "t1"),
    pre_variable = sub("time2$", "time1", variable)
  )
consensus <- bind_rows(consensus_1, consensus_2) |>
  left_join(consensus_items, by = c("event_id", "pre_variable"), relationship = "many-to-one")
stopifnot(
  !anyNA(consensus$item_id), !anyNA(consensus$rating),
  all(with(consensus, rating >= lower & rating <= upper))
)
consensus <- consensus |>
  mutate(rating = (rating - lower) / (upper - lower), education = NA, income = NA, combined = NA) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, consensus |>
  summarise(
    starting_rows = n_distinct(participant_id), eligible_participants = starting_rows,
    groups = n_distinct(group_id), items = n_distinct(item_id),
    note = paste(
      "Study1 uses unique id rather than nonunique ppnr; released sample already excludes",
      "four non-native-Dutch-containing groups. Study2 uses group crossed with ppnr."
    ),
    .by = event_id
  ))
