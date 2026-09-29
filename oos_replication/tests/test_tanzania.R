library(testthat)

source_flow <- tibble()
source(file.path(dp_project_root(), "oos_replication", "scripts", "prepare_tanzania.R"),
  local = TRUE
)

test_that("Tanzania preserves the released roster and documented waves", {
  expect_equal(nrow(tanzania), 371L * 22L)
  expect_equal(n_distinct(tanzania$participant_id), 371L)
  expect_equal(n_distinct(tanzania$item_id), 22L)
  expect_equal(n_distinct(paste(tanzania$episode_id, tanzania$group_id)), 50L)
  expect_equal(sum(tz_demographics$gender, na.rm = TRUE), 182L)
  expect_equal(sum(!tz_demographics$gender, na.rm = TRUE), 188L)
  expect_equal(sum(is.na(tz_demographics$gender)), 1L)
  expect_true(all(is.na(tanzania$education)))
  expect_true(all(is.na(tanzania$income)))
  expect_true(all(is.na(tanzania$combined)))
  expect_equal(nrow(tz_responses), 97900L)
  expect_true(all(is.na(tz_responses$group_id[tz_responses$source_sample != "Citizens"])))
  expect_setequal(tz_observed$wave, c("t0", "t3"))
  expect_identical(unique(tanzania$initial_wave), "t0")
  expect_identical(unique(tanzania$later_wave), "t3")
  expect_equal(sum(is.na(delegates_tz$zdelib)), 1L)
  expect_equal(source_flow$items, 22L)
})

test_that("Tanzania consumes upstream values without local recodes", {
  actual <- tanzania |>
    select(participant_id, item_id, episode_id, group_id, t1, t2) |>
    pivot_longer(c(t1, t2), names_to = "wave", values_to = "value") |>
    arrange(participant_id, item_id, wave)
  expected <- tz_observed |>
    transmute(participant_id = source_unit_id, item_id = attitude_id,
      episode_id = discussion_round, group_id,
      wave = if_else(wave == "t0", "t1", "t2"), value
    ) |>
    arrange(participant_id, item_id, wave)
  expect_identical(actual, expected)
  expect_true(all(is.na(tz_observed$value[tz_observed$response_status != "answered"])))
  borrowing <- filter(tanzania, item_id == "borrowing_opposition")
  expect_equal(sum(!is.na(borrowing$t1)), 370L)
  expect_equal(sum(!is.na(borrowing$t2)), 361L)
  expect_equal(sum(!is.na(borrowing$t1) & !is.na(borrowing$t2)), 360L)
  expect_equal(n_distinct(borrowing$group_id), 25L)
  expect_identical(unique(borrowing$episode_id), "round_1")
})

test_that("existing 21 Tanzania items retain their estimates and samples", {
  old_items <- filter(tanzania, item_id != "borrowing_opposition")
  summary <- purrr::map_dfr(c("paired", "available"), \(x) score_groups(old_items, x)) |>
    filter(metric %in% c("h", "p", "p_absolute", "d_gender")) |>
    summarise(pairs = sum(!is.na(estimate)), mean = mean(estimate, na.rm = TRUE),
      .by = c(membership, metric)
    ) |>
    arrange(membership, metric)
  expect_identical(summary$pairs, c(517L, 525L, 519L, 525L, 517L, 525L, 520L, 525L))
  expect_equal(summary$mean, c(
    -0.00840860085540938, -0.00556495482044937,
    -0.036964365114654125, -0.005957962672248376,
    -0.005371478403393306, -0.005110639111677843,
    -0.03830942401615479, -0.007626856212570503
  ), tolerance = 1e-12)
})

test_that("all 22 Tanzania items have verified sample counts and estimates", {
  summary <- purrr::map_dfr(c("paired", "available"), \(x) score_groups(tanzania, x)) |>
    filter(metric %in% c("h", "p", "p_absolute", "d_gender")) |>
    summarise(pairs = sum(!is.na(estimate)), mean = mean(estimate, na.rm = TRUE),
      .by = c(membership, metric)
    ) |>
    arrange(membership, metric)
  expect_identical(summary$pairs, c(541L, 550L, 542L, 550L, 541L, 550L, 542L, 550L))
  expect_equal(summary$mean, c(
    -0.0100909375077582, -0.0080058999937500,
    -0.0373342186718571, -0.0033462370962371,
    -0.0072195251862535, -0.0074624692886250,
    -0.0394003070525211, -0.0050844599844600
  ), tolerance = 1e-12)
})
