panel <- haven::read_dta(oos_source_path("tanzania.dta"))
assignments <- readr::read_tsv(oos_source_path("tanzania_groups.tab"), show_col_types = FALSE)
stopifnot(
  nrow(assignments) == 371L, !anyDuplicated(assignments$HHID),
  !anyDuplicated(panel$HHID), !anyNA(assignments),
  setequal(assignments$group1, 1:25), setequal(assignments$group2, 1:25),
  all(assignments$HHID %in% panel$HHID)
)
tz_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "tanzania_2015")
delegates_tz <- assignments |>
  left_join(panel, by = "HHID", relationship = "one-to-one")
stopifnot(
  all(is.na(delegates_tz$zdelib) | delegates_tz$zdelib == 1),
  sum(is.na(delegates_tz$zdelib)) == 1L, nrow(delegates_tz) == 371L
)

tanzania <- delegates_tz |>
  transmute(
    participant_id = as.character(HHID), group1, group2,
    gender = as.numeric(male) == 1,
    education = NA, income = NA, combined = NA,
    across(all_of(c(tz_items$pre_variable, tz_items$post_variable)), as.numeric)
  ) |>
  pivot_longer(matches("^H[1-4][1-8][01]$"), names_to = "variable", values_to = "rating") |>
  mutate(
    wave = if_else(endsWith(variable, "0"), "t1", "t2"),
    pre_variable = sub("1$", "0", variable)
  ) |>
  left_join(tz_items, by = "pre_variable", relationship = "many-to-one")
stopifnot(
  !anyNA(tanzania$item_id),
  all(is.na(tanzania$rating) | tanzania$rating %in% c(-99, -97, 98, 99) |
        between(tanzania$rating, tanzania$lower, tanzania$upper))
)
tanzania <- tanzania |>
  mutate(
    rating = if_else(rating %in% c(-99, -97, 98, 99), NA_real_, rating),
    rating = (rating - lower) / (upper - lower),
    group_id = as.character(if_else(episode_id == "round_1", group1, group2))
  ) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, tibble(
  event_id = "tanzania_2015", starting_rows = nrow(panel),
  eligible_participants = nrow(delegates_tz), groups = 50L, items = nrow(tz_items),
  note = paste(
    "371 released group assignments: 370 flagged zdelib=1; one flag missing.",
    "31 further zdelib=1 citizens lack group assignments and cannot enter.",
    "25 groups per round, same people reassigned; 50 group-episodes, one family.",
    "H26 omitted: appendix says seven categories, released labels specify five."
  )
))
