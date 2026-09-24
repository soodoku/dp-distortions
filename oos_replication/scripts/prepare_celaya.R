raw_celaya <- readr::read_csv(oos_source_path("celaya.csv"), show_col_types = FALSE,
  name_repair = "minimal", col_types = readr::cols(.default = readr::col_character())
)
celaya_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "celaya")
# Select unique source columns before manipulating the released blank spreadsheet columns.
celaya <- raw_celaya[c(
  "SESSION", "Type", "FEMALE", "EDUCATION", "HH_INCOME",
  celaya_items$pre_variable, celaya_items$post_variable
)] |>
  mutate(participant_id = as.character(row_number())) |>
  filter(Type == "1") |>
  mutate(across(-participant_id, as.numeric))
stopifnot(
  nrow(raw_celaya) == 207L, nrow(celaya) == 104L,
  setequal(celaya$SESSION, c(2, 4, 5, 7, 10, 12, 13)),
  all(celaya$FEMALE %in% 0:1), all(celaya$EDUCATION %in% 1:8),
  all(is.na(celaya$HH_INCOME) | celaya$HH_INCOME %in% 1:12)
)
celaya <- celaya |>
  transmute(
    event_id = paste0("celaya_", SESSION), participant_id, group_id = as.character(SESSION),
    gender = FEMALE == 0, education = EDUCATION, income = HH_INCOME,
    across(all_of(c(celaya_items$pre_variable, celaya_items$post_variable)))
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
  pivot_longer(matches("^(INITIAL|FINAL)_"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(startsWith(variable, "INITIAL_"), "t1", "t2"),
    pre_variable = sub("^FINAL_", "INITIAL_", variable)
  ) |>
  left_join(select(celaya_items, -event_id), by = "pre_variable", relationship = "many-to-one")
stopifnot(!anyNA(celaya$item_id), all(celaya$rating %in% -2:2))
celaya <- celaya |>
  mutate(rating = (rating + 2) / 4) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, celaya |>
  summarise(
    starting_rows = n_distinct(participant_id), eligible_participants = starting_rows,
    groups = 1L, items = 8L,
    note = "104 deliberators of 207 released rows; exclude 103 Q&A respondents; source row IDs.",
    .by = event_id
  ))
