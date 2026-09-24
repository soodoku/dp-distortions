source("scripts/00_functions.R")

hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv")
scores <- bind_rows(
  hp |>
    transmute(poll_id, group_key, issue_id, measure = "H",
      available = homoex, paired = homoex_cc
    ),
  hp |>
    transmute(poll_id, group_key, issue_id, measure = "P",
      available = polarex, paired = polarex_cc
    ),
  map(c("gender", "educ", "income", "triple"), \(dimension) {
    read.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", dimension)) |>
      transmute(poll_id, group_key, issue_id, measure = paste0("D_", dimension),
        available = ext_grp, paired = ext_grp_paired
      )
  }) |>
    list_rbind()
)

paired_comparison <- scores |>
  pivot_longer(c(available, paired), names_to = "sample", values_to = "score") |>
  filter(!is.na(score)) |>
  nest(.by = c(measure, sample)) |>
  mutate(result = map(data, \(observations) {
    model <- lm(score ~ 1, data = observations)
    clubSandwich::conf_int(model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite", p_values = TRUE
    ) |>
      as_tibble() |>
      transmute(estimate = beta, se = SE, df, conf_low = CI_L, conf_high = CI_U,
        p = p_val, n_pairs = nrow(observations), n_polls = n_distinct(observations$poll_id)
      )
  })) |>
  select(-data) |>
  unnest(result)

frequency_comparison <- scores |>
  filter(!is.na(available)) |>
  mutate(direction = case_when(
    abs(available) <= movement_eps ~ 0,
    available > 0 ~ 1,
    TRUE ~ -1
  )) |>
  nest(.by = measure) |>
  mutate(result = map(data, \(observations) {
    parity_model <- lm(direction ~ 1, data = observations)
    majority_model <- lm(I(direction > 0) ~ 1, data = observations)
    majority_test <- clubSandwich::coef_test(majority_model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite", null_constants = .5
    )
    clubSandwich::conf_int(parity_model,
      vcov = "CR2", cluster = observations$poll_id,
      test = "Satterthwaite", p_values = TRUE
    ) |>
      as_tibble() |>
      transmute(
        positive = mean(observations$direction > 0),
        unchanged = mean(observations$direction == 0),
        negative = mean(observations$direction < 0),
        p_majority = majority_test$p_Satt,
        positive_minus_negative = beta,
        se = SE, df, conf_low = CI_L, conf_high = CI_U, p_parity = p_val,
        n_pairs = nrow(observations), n_polls = n_distinct(observations$poll_id)
      )
  })) |>
  select(-data) |>
  unnest(result)

write.csv(paired_comparison, "tabs/09_paired_response_sensitivity.csv", row.names = FALSE)
write.csv(frequency_comparison, "tabs/09_frequency_comparison.csv", row.names = FALSE)
