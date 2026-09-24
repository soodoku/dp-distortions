raw_shizuoka <- readr::read_tsv(oos_source_path("shizuoka.tsv"), show_col_types = FALSE)
shizuoka_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "shizuoka_2019")
stopifnot(
  nrow(raw_shizuoka) == 65L, !anyDuplicated(raw_shizuoka),
  identical(as.integer(table(raw_shizuoka$group)), c(8L, 6L, 8L, 8L, 8L, 9L, 9L, 9L)),
  all(raw_shizuoka$`gender(male)` %in% 0:1),
  all(raw_shizuoka$`gender(male)` + raw_shizuoka$`gender(female)` == 1),
  all(is.na(raw_shizuoka$education) | raw_shizuoka$education %in% 1:4)
)
shizuoka <- raw_shizuoka |>
  transmute(
    event_id = "shizuoka_2019", participant_id = as.character(row_number()), group_id = group,
    gender = `gender(male)` == 1,
    education = education > median(education, na.rm = TRUE), income = NA, combined = NA,
    across(all_of(c(shizuoka_items$pre_variable, shizuoka_items$post_variable)))
  ) |>
  pivot_longer(matches("^T[23]_S"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(startsWith(variable, "T2_"), "t1", "t2"),
    pre_variable = sub("^T3_", "T2_", variable)
  ) |>
  left_join(select(shizuoka_items, -event_id), by = "pre_variable", relationship = "many-to-one")
stopifnot(!anyNA(shizuoka$item_id), all(is.na(shizuoka$rating) | shizuoka$rating %in% 1:5))
shizuoka <- shizuoka |>
  mutate(rating = (rating - lower) / (upper - lower)) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, tibble(
  event_id = "shizuoka_2019", starting_rows = 65L, eligible_participants = 65L,
  groups = 8L, items = 11L,
  note = "Released face-to-face sample; source-row IDs; T2 before and T3 after discussion."
))
