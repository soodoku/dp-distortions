raw_oboe <- readr::read_tsv(oos_source_path("oboe.tab"), show_col_types = FALSE)
stopifnot(nrow(raw_oboe) == 2793L, !anyDuplicated(raw_oboe$oboe_w1id))
oboe_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "oboe")

oboe_participants <- raw_oboe |>
  mutate(
    pre_table = as.numeric(oboe_pr_table_numb),
    post_table = as.numeric(oboe_pt_table_numb),
    event_id = paste0("oboe_", oboe_pr_event)
  )
stopifnot(
  !anyNA(oboe_participants$pre_table), !anyNA(oboe_participants$post_table),
  all(oboe_participants$sitetable ==
        100 * oboe_participants$oboe_pr_event + oboe_participants$pre_table),
  sum(oboe_participants$pre_table != oboe_participants$post_table) == 42L
)
oboe_flow <- oboe_participants |>
  summarise(
    starting_rows = n(), eligible_participants = sum(pre_table == post_table),
    groups = n_distinct(sitetable[pre_table == post_table]), items = nrow(oboe_items),
    note = "Exclude conflicting pre/post table assignments; retain documented pre-table key.",
    .by = event_id
  )

oboe <- oboe_participants |>
  filter(pre_table == post_table) |>
  transmute(
    event_id, participant_id = as.character(oboe_w1id), group_id = as.character(sitetable),
    gender = oboe_PR_SEX == 0, education = oboe_PR_EDUC, income = oboe_PR_FAMINC,
    across(all_of(c(oboe_items$pre_variable, oboe_items$post_variable)))
  ) |>
  mutate(
    education = education > median(education, na.rm = TRUE),
    income = income > median(income, na.rm = TRUE),
    combined = if_else(
      is.na(gender) | is.na(education) | is.na(income), NA,
      gender & education & income
    ),
    .by = event_id
  ) |>
  pivot_longer(starts_with("oboe_P"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(startsWith(variable, "oboe_PR"), "t1", "t2"),
    pre_variable = sub("oboe_PT", "oboe_PR", variable)
  ) |>
  left_join(select(oboe_items, -event_id), by = "pre_variable", relationship = "many-to-one")
stopifnot(!anyNA(oboe$item_id), all(is.na(oboe$rating) | oboe$rating %in% 1:5))
oboe <- oboe |>
  mutate(rating = (rating - 1) / 4) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, oboe_flow)
