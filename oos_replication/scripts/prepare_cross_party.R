raw_cross_party <- readRDS(oos_source_path("cross_party.rds"))
cross_party_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "cross_party_2021")
cross_party_participants <- raw_cross_party |>
  filter(Z == 1, full_cluster)
stopifnot(
  nrow(raw_cross_party) == 3483L, nrow(cross_party_participants) == 294L,
  n_distinct(cross_party_participants$cluster_id) == 147L,
  all(table(cross_party_participants$cluster_id) == 2L),
  !anyDuplicated(cross_party_participants$id), nrow(cross_party_items) == 9L
)
cross_party <- cross_party_participants |>
  transmute(
    participant_id = as.character(id), group_id = as.character(cluster_id),
    gender = if_else(gender %in% c("Male", "Female"), gender == "Male", NA),
    education = NA, income = NA, combined = NA,
    across(all_of(c(cross_party_items$pre_variable, cross_party_items$post_variable)))
  ) |>
  pivot_longer(starts_with("ft_"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(endsWith(variable, "_post"), "t2", "t1"),
    pre_variable = sub("_post$", "_pre", variable)
  ) |>
  left_join(cross_party_items, by = "pre_variable", relationship = "many-to-one")
stopifnot(
  !anyNA(cross_party$item_id),
  all(is.na(cross_party$rating) | between(cross_party$rating, 0, 100))
)
cross_party <- cross_party |>
  mutate(rating = rating / 100) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, tibble(
  event_id = "cross_party_2021", starting_rows = nrow(raw_cross_party),
  eligible_participants = 294L, groups = 147L, items = 9L,
  note = paste(
    "516 discussion-assigned; 294 participants in 147 partnerships where both completed",
    "the chat (author full_cluster flag). Missing transcripts do not trigger exclusion."
  )
))
