raw_echo <- haven::read_sav(oos_source_path("echo.sav"))
echo_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "echo_2021")
echo_participants <- raw_echo |>
  mutate(participant_id = as.character(row_number())) |>
  filter(composition %in% c("con", "lab", "mixed")) |>
  mutate(
    documented_key = paste(format(session_date, "%d_%m"), session_time, session_fac, sep = "_"),
    eligible = !is.na(session_code) & session_code != "NA" &
      session_code == documented_key & session_size != 98
  )
stopifnot(nrow(echo_participants) == 658L, sum(echo_participants$eligible) == 653L)
echo_flow <- echo_participants |>
  summarise(
    starting_rows = n(), eligible_participants = sum(eligible),
    groups = n_distinct(session_code[eligible]), items = 4L,
    note = paste(
      "Exclude 3 missing keys, 1 inconsistent key/date and 1 contradictory control-size flag",
      "across discussion arms; retain valid two-person group. Source row IDs."
    ),
    .by = composition
  ) |>
  mutate(event_id = paste0("echo_", composition)) |>
  select(-composition)
echo_participants <- filter(echo_participants, eligible)
stopifnot(
  n_distinct(echo_participants$session_code) == 87L,
  all(as.Date(echo_participants$EndDate) <= echo_participants$session_date, na.rm = TRUE),
  all(as.Date(echo_participants$EndDateW2) >= echo_participants$session_date, na.rm = TRUE)
)
echo <- echo_participants |>
  transmute(
    event_id = paste0("echo_", composition), participant_id, group_id = session_code,
    gender = if_else(SC_gender %in% c("Man", "Woman"), SC_gender == "Man", NA),
    education = NA, income = NA, combined = NA,
    across(all_of(c(echo_items$pre_variable, echo_items$post_variable)), as.numeric)
  ) |>
  pivot_longer(matches("^NP"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(endsWith(variable, "W2"), "t2", "t1"),
    pre_variable = sub("W2$", "", variable)
  ) |>
  left_join(select(echo_items, -event_id), by = "pre_variable", relationship = "many-to-one")
stopifnot(!anyNA(echo$item_id), all(is.na(echo$rating) | echo$rating %in% c(0:10, 97, 99)))
echo <- echo |>
  mutate(rating = if_else(rating %in% c(97, 99), NA_real_, rating / 10)) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, echo_flow)
