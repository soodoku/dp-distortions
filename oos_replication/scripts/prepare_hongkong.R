raw_hongkong <- haven::read_sav(oos_source_path("hongkong.sav"))
stopifnot(
  nrow(raw_hongkong) == 12L, !anyDuplicated(raw_hongkong$ID),
  all(table(raw_hongkong$Group) == 6L)
)
hongkong <- raw_hongkong |>
  transmute(
    event_id = if_else(Group == 1, "hongkong_deliberation", "hongkong_discussion"),
    episode_id = "main", participant_id = as.character(ID), group_id = as.character(Group),
    item_id = "article_23", construct = "policy", midpoint = 0.5,
    t1 = as.numeric(T1_QA_1) / 10, t2 = as.numeric(T2_QA_1) / 10,
    gender = NA, education = NA, income = NA, combined = NA
  )
source_flow <- bind_rows(source_flow, hongkong |>
  summarise(
    starting_rows = n(), eligible_participants = n(), groups = 1L, items = 1L,
    note = "Study 1 actual discussion groups; study 2 video viewers excluded.", .by = event_id
  ))
