# Thresholds use the participating event sample before item-specific missingness.
thresholds <- bind_rows(
  delegates |>
    transmute(event_id = "a1r_2019", education = EDUC4, income = NA_real_),
  climate_delegates |>
    transmute(event_id = "a1r_climate_2021", education = EDUC5, income = INCOME),
  oboe_participants |>
    filter(pre_table == post_table) |>
    transmute(event_id, education = oboe_PR_EDUC, income = oboe_PR_FAMINC),
  raw_celaya[c("SESSION", "Type", "EDUCATION", "HH_INCOME")] |>
    filter(Type == "1") |>
    transmute(
      event_id = paste0("celaya_", SESSION),
      education = as.numeric(EDUCATION), income = as.numeric(HH_INCOME)
    ),
  whatsapp_participants |>
    transmute(event_id, education = education_score, income = incomeamnt),
  raw_shizuoka |>
    transmute(event_id = "shizuoka_2019", education, income = NA_real_)
) |>
  pivot_longer(c(education, income), names_to = "dimension", values_to = "score") |>
  summarise(
    threshold = median(score, na.rm = TRUE),
    tied_at_threshold = sum(score == threshold, na.rm = TRUE),
    .by = c(event_id, dimension)
  ) |>
  mutate(tied_at_threshold = if_else(is.na(threshold), NA_integer_, tied_at_threshold))

demographics <- ratings |>
  distinct(event_id, participant_id, gender, education, income, combined) |>
  pivot_longer(c(gender, education, income, combined),
    names_to = "dimension", values_to = "advantaged"
  ) |>
  summarise(
    participants = n(), n_advantaged = sum(advantaged, na.rm = TRUE),
    n_disadvantaged = sum(!advantaged, na.rm = TRUE), n_missing = sum(is.na(advantaged)),
    .by = c(event_id, dimension)
  ) |>
  left_join(thresholds, by = c("event_id", "dimension"), relationship = "one-to-one")
stopifnot(all(with(demographics, participants == n_advantaged + n_disadvantaged + n_missing)))
readr::write_csv(demographics, "oos_replication/tabs/demographics.csv")
