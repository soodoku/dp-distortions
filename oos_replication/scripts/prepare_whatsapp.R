whatsapp_data <- new.env()
load(oos_source_path("whatsapp.RData"), envir = whatsapp_data)
raw_whatsapp <- whatsapp_data$d
whatsapp_items <- readr::read_csv("oos_replication/items.csv", show_col_types = FALSE) |>
  filter(event_id == "whatsapp")
stopifnot(
  nrow(raw_whatsapp) == 1070L, n_distinct(raw_whatsapp$idthread) == 535L,
  !anyDuplicated(raw_whatsapp$s1.ResponseId), nrow(whatsapp_items) == 18L
)
whatsapp_participants <- raw_whatsapp |>
  filter(condition_topic %in% c("gen", "igr")) |>
  mutate(
    event_id = paste("whatsapp", condition_topic, condition_pair, sep = "_"),
    education_score = match(education, c("ClassIXorbelow", "ClassX", "ClassXII", "UG", "PG"))
  )
stopifnot(
  nrow(whatsapp_participants) == 712L,
  n_distinct(whatsapp_participants$idthread) == 356L,
  all(table(whatsapp_participants$idthread) == 2L),
  !anyNA(whatsapp_participants$education_score),
  all(whatsapp_participants$gender_f %in% 0:1),
  all(is.na(whatsapp_participants$incomeamnt) |
        between(whatsapp_participants$incomeamnt, 0, 1e7))
)
whatsapp <- whatsapp_participants |>
  transmute(
    event_id, participant_id = s1.ResponseId, group_id = idthread,
    gender = gender_f == 0, education = education_score, income = incomeamnt,
    across(all_of(c(whatsapp_items$pre_variable, whatsapp_items$post_variable)))
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
  pivot_longer(matches("^(post\\.)?(feelth_|gr_)"),
    names_to = "variable", values_to = "rating"
  ) |>
  mutate(
    wave = if_else(startsWith(variable, "post."), "t2", "t1"),
    pre_variable = sub("^post\\.", "", variable)
  ) |>
  left_join(select(whatsapp_items, -event_id),
    by = "pre_variable", relationship = "many-to-one"
  )
stopifnot(!anyNA(whatsapp$item_id), all(is.na(whatsapp$rating) | whatsapp$rating %in% 1:5))
whatsapp <- whatsapp |>
  mutate(rating = (rating - 1) / 4) |>
  select(
    event_id, episode_id, participant_id, group_id, item_id, construct, midpoint,
    gender, education, income, combined, wave, rating
  ) |>
  pivot_wider(names_from = wave, values_from = rating)
source_flow <- bind_rows(source_flow, whatsapp_participants |>
  summarise(
    starting_rows = n(), eligible_participants = n(), groups = n_distinct(idthread),
    items = nrow(whatsapp_items),
    note = paste(
      "Political/intergroup prompts: 712 of 1070 conversation completers;",
      "exclude 358 nonpolitical-prompt participants. Retain missing post ratings."
    ),
    .by = event_id
  ))
