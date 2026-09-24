raw <- readr::read_tsv(
  oos_source_path("a1r.tab"), show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_double())
)
stopifnot(nrow(raw) == 3842L, ncol(raw) == 150L)

delegates <- raw |>
  mutate(participant_id = as.character(row_number())) |>
  filter(CONDITION == 1, POST == 1, !is.na(GROUP))
stopifnot(nrow(delegates) == 523L, n_distinct(delegates$GROUP) == 40L)

a1r_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "a1r_2019")
stopifnot(nrow(a1r_items) == 47L)

a1r <- delegates |>
  transmute(
    participant_id, group_id = as.character(GROUP),
    gender = if_else(GENDER %in% 1:2, GENDER == 1, NA),
    education = if_else(EDUC4 %in% 1:4, EDUC4, NA_real_),
    across(all_of(c(a1r_items$pre_variable, a1r_items$post_variable)))
  ) |>
  mutate(
    education = education > median(education, na.rm = TRUE),
    income = NA, combined = NA
  ) |>
  pivot_longer(matches("^(T2)?Q[2-6][A-J]$"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(startsWith(variable, "T2"), "t2", "t1"),
    pre_variable = sub("^T2", "", variable)
  ) |>
  left_join(a1r_items, by = "pre_variable", relationship = "many-to-one")

stopifnot(
  !anyNA(a1r$item_id),
  all(is.na(a1r$rating) | a1r$rating %in% c(0:10, -8, 77, 98, 99))
)

a1r <- a1r |>
  mutate(rating = if_else(rating %in% c(-8, 77, 98, 99), NA_real_, rating / 10)) |>
  select(
    event_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating) |>
  mutate(episode_id = "main")

source_flow <- tibble(
  event_id = "a1r_2019", starting_rows = nrow(raw),
  eligible_participants = nrow(delegates), groups = n_distinct(delegates$GROUP),
  items = nrow(a1r_items), note = paste(
    "523 delegates with POST=1 and GROUP observed; 3 other GROUP-assigned rows",
    "lack POST completion. Participant ID is a source row identifier, not a cross-study ID."
  )
)
