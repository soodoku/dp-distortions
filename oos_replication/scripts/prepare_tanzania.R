panel <- haven::read_dta(oos_source_path("tanzania.dta"))
assignments <- readr::read_tsv(oos_source_path("tanzania_groups.tab"), show_col_types = FALSE)
tz_definitions <- arrow::read_parquet(oos_source_path("tanzania_attitude_definitions.parquet"))
tz_responses <- arrow::read_parquet(oos_source_path("tanzania_attitude_responses.parquet"))
stopifnot(
  nrow(assignments) == 371L, !anyDuplicated(assignments$HHID),
  !anyDuplicated(panel$HHID), !anyNA(assignments),
  setequal(assignments$group1, 1:25), setequal(assignments$group2, 1:25),
  all(assignments$HHID %in% panel$HHID),
  nrow(tz_definitions) == 22L,
  !anyDuplicated(tz_definitions[c("source_id", "attitude_id")]),
  nrow(tz_responses) == nrow(panel) * nrow(tz_definitions) * 2L,
  !anyDuplicated(tz_responses[c("source_id", "source_row", "attitude_id", "source_wave")])
)
delegates_tz <- assignments |>
  left_join(panel, by = "HHID", relationship = "one-to-one")
stopifnot(
  all(is.na(delegates_tz$zdelib) | delegates_tz$zdelib == 1),
  sum(is.na(delegates_tz$zdelib)) == 1L, nrow(delegates_tz) == 371L
)
tz_roster <- assignments |>
  transmute(participant_id = as.character(HHID),
    round_1 = as.character(group1), round_2 = as.character(group2)
  ) |>
  pivot_longer(c(round_1, round_2), names_to = "discussion_round", values_to = "roster_group")
tz_demographics <- delegates_tz |>
  transmute(participant_id = as.character(HHID), gender = as.numeric(male) == 1,
    education = NA, income = NA, combined = NA
  )

tz_observed <- tz_responses |>
  filter(!is.na(group_id)) |>
  left_join(tz_definitions |> select(source_id, attitude_id, midpoint),
    by = c("source_id", "attitude_id"), relationship = "many-to-one"
  ) |>
  left_join(tz_roster,
    by = c("source_unit_id" = "participant_id", "discussion_round"),
    relationship = "many-to-one"
  )
stopifnot(
  nrow(tz_observed) == 371L * 22L * 2L,
  !anyNA(tz_observed$midpoint), !anyNA(tz_observed$roster_group),
  all(tz_observed$group_id == tz_observed$roster_group),
  setequal(tz_observed$source_unit_id, as.character(assignments$HHID)),
  all(tz_observed$source_sample == "Citizens"),
  all(tz_observed$wave %in% c("t0", "t3")),
  all(tz_observed$wave_role == if_else(tz_observed$wave == "t0", "pre_arrival", "follow_up")),
  all(is.na(tz_observed$value) | between(tz_observed$value, 0, 1))
)

tanzania <- tz_observed |>
  transmute(
    event_id = "tanzania_2015", episode_id = discussion_round,
    participant_id = source_unit_id, group_id, item_id = attitude_id,
    construct = "policy", midpoint, initial_wave = "t0", later_wave = "t3",
    wave = if_else(wave == "t0", "t1", "t2"), rating = value
  ) |>
  left_join(tz_demographics, by = "participant_id", relationship = "many-to-one") |>
  pivot_wider(names_from = wave, values_from = rating)
stopifnot(
  nrow(tanzania) == 371L * 22L,
  !anyDuplicated(tanzania[c("participant_id", "episode_id", "item_id")])
)
source_flow <- bind_rows(source_flow, tibble(
  event_id = "tanzania_2015", starting_rows = nrow(panel),
  eligible_participants = nrow(delegates_tz), groups = 50L, items = nrow(tz_definitions),
  note = paste(
    "371 released group assignments: 370 flagged zdelib=1; one flag missing.",
    "31 further zdelib=1 citizens lack group assignments and cannot enter.",
    "25 groups per round, same people reassigned; 50 group-episodes, one family.",
    "22 central items: t0 baseline to t3 telephone follow-up, not immediate exit.",
    "Values, missingness, item definitions and H26 five-category scale are upstream."
  )
))
