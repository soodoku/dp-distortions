raw_diplomacy <- haven::read_sav(oos_source_path("diplomacy3.sav"))
diplomacy_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "diplomacy")
stopifnot(
  nrow(raw_diplomacy) == 105L, n_distinct(raw_diplomacy$Q1.2) == 35L,
  !anyDuplicated(raw_diplomacy[c("Q1.1", "Q1.2")]),
  all(raw_diplomacy$Q1.3 %in% 1:2),
  all(raw_diplomacy$Q4.1 %in% 1:10), all(raw_diplomacy$Q8.1 %in% 1:10)
)
diplomacy <- bind_rows(
  raw_diplomacy |>
    transmute(
      group_id = as.character(Q1.2), participant_id = paste(Q1.2, Q1.1, sep = ":"),
      gender = if_else(Q11.3 %in% 1:2, Q11.3 == 1, NA), episode_id = "first",
      topic = as.numeric(Q4.1), experimental = Q1.3 == 1,
      t1 = as.numeric(Q5.1_1), t2 = as.numeric(Q6.2_1)
    ),
  raw_diplomacy |>
    transmute(
      group_id = as.character(Q1.2), participant_id = paste(Q1.2, Q1.1, sep = ":"),
      gender = if_else(Q11.3 %in% 1:2, Q11.3 == 1, NA), episode_id = "second",
      topic = as.numeric(Q8.1), experimental = Q1.3 == 2,
      t1 = as.numeric(Q9.1_1), t2 = as.numeric(Q10.2_1)
    )
) |>
  mutate(
    event_id = if_else(experimental, "diplomacy_experimental", "diplomacy_control"),
    item_id = paste0("topic_", topic)
  )
assignments <- diplomacy |> summarise(
  topics = n_distinct(topic), conditions = n_distinct(experimental), .by = c(group_id, episode_id)
)
stopifnot(
  all(assignments$topics == 1L), all(assignments$conditions == 1L),
  all(diplomacy$t1 %in% 1:5), all(diplomacy$t2 %in% 1:5)
)
diplomacy <- diplomacy |>
  left_join(select(diplomacy_items, episode_id, item_id, construct, midpoint),
    by = c("episode_id", "item_id"), relationship = "many-to-one"
  ) |>
  transmute(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education = NA, income = NA, combined = NA,
    t1 = (t1 - 1) / 4, t2 = (t2 - 1) / 4
  )
source_flow <- bind_rows(source_flow, diplomacy |>
  summarise(
    starting_rows = n_distinct(participant_id), eligible_participants = starting_rows,
    groups = n_distinct(group_id), items = n_distinct(item_id),
    note = paste(
      "The same 105 people in 35 triads discuss two selected topics under opposite",
      "condition orders. Policy and social judgments are separate constructs."
    ),
    .by = event_id
  ))
