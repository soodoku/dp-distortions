raw_climate <- readr::read_tsv(oos_source_path("climate.tab"), show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
climate_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "a1r_climate_2021")
climate_delegates <- raw_climate |>
  filter(FINAL_ATTEND == "8") |>
  mutate(
    group_id = paste(ROOM, T2P_OPTION, sep = ":"),
    across(c(GENDER, EDUC5, INCOME), as.numeric)
  )
stopifnot(
  nrow(climate_delegates) == 962L, !anyDuplicated(climate_delegates$CaseId),
  !anyNA(climate_delegates[c("ROOM", "T2P_OPTION")]),
  n_distinct(climate_delegates$group_id) == 105L, nrow(climate_items) == 72L,
  sum(climate_delegates$DELEGATE2019 == "1", na.rm = TRUE) == 139L,
  all(climate_delegates$GENDER %in% 1:2), all(climate_delegates$EDUC5 %in% 1:5),
  all(climate_delegates$INCOME %in% 1:18)
)
climate <- climate_delegates |>
  transmute(
    participant_id = CaseId, group_id, gender = GENDER == 1,
    education = EDUC5 > median(EDUC5), income = INCOME > median(INCOME),
    combined = gender & education & income,
    across(all_of(c(climate_items$pre_variable, climate_items$post_variable)), as.numeric)
  ) |>
  pivot_longer(matches("^(T2)?Q[0-9]+[A-Z]$"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(startsWith(variable, "T2"), "t2", "t1"),
    pre_variable = sub("^T2", "", variable)
  ) |>
  left_join(climate_items, by = "pre_variable", relationship = "many-to-one")
stopifnot(
  !anyNA(climate$item_id), all(is.na(climate$rating) | climate$rating %in% c(0:10, 77, 88, 98, 99))
)
climate <- climate |>
  mutate(rating = if_else(rating %in% c(77, 88, 98, 99), NA_real_, rating / 10)) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, tibble(
  event_id = "a1r_climate_2021", starting_rows = nrow(raw_climate),
  eligible_participants = nrow(climate_delegates), groups = 105L, items = 72L,
  note = paste(
    "ROOM crossed with schedule option; 139 attendees also participated in A1R2019.",
    "65 policy items plus 3 concern and 4 belief items in separate outcome strata."
  )
))
