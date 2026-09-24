library(testthat)

example_ratings <- tibble(
  event_id = "example", episode_id = "first", group_id = "group", item_id = "issue",
  participant_id = c("a", "b"), construct = "policy", midpoint = 0.5,
  t1 = c(0.2, 0.6), t2 = c(0.3, 0.7),
  gender = c(FALSE, TRUE), education = NA, income = NA, combined = NA
)

test_that("hand-calculated movement and sample SD agree", {
  result <- score_groups(example_ratings)
  expect_equal(result$estimate[result$metric == "h"], 0, tolerance = 1e-12)
  expect_equal(result$estimate[result$metric == "p"], -0.1)
  expect_equal(result$estimate[result$metric == "d_gender"], 0.1)
  expect_true(is.na(result$estimate[result$metric == "d_income"]))
  spread <- score_groups(mutate(example_ratings, t1 = c(0, 1), t2 = c(0.4, 0.6)))
  expect_equal(spread$estimate[spread$metric == "h"], sqrt(0.5) - sqrt(0.02))
  expect_true(is.na(spread$estimate[spread$metric == "p"]))
  no_midpoint <- score_groups(mutate(example_ratings, midpoint = NA_real_))
  expect_true(is.na(no_midpoint$estimate[no_midpoint$metric == "p"]))
  expect_equal(no_midpoint$estimate[no_midpoint$metric == "d_gender"], 0.1)
})

test_that("midpoint crossings, ties and zero movement remain distinct", {
  crossing <- score_groups(mutate(example_ratings, t1 = c(0.1, 0.3), t2 = c(0.8, 1)))
  expect_equal(crossing$estimate[crossing$metric == "p"], -0.7)
  expect_equal(crossing$estimate[crossing$metric == "p_absolute"], 0.1)
  zero <- score_groups(mutate(example_ratings, t2 = t1))
  expect_equal(zero$estimate[zero$metric == "d_gender"], 0)
  tied <- score_groups(mutate(example_ratings, t1 = c(0.2, 0.2)))
  expect_true(is.na(tied$estimate[tied$metric == "d_gender"]))
})

test_that("pairing and empty subgroup means do not manufacture zero", {
  d <- mutate(example_ratings, t2 = c(0.3, NA_real_))
  paired <- score_groups(d, "paired")
  available <- score_groups(d, "available")
  expect_true(is.na(paired$estimate[paired$metric == "h"]))
  expect_equal(paired$estimate[paired$metric == "p"], -0.1)
  expect_equal(available$estimate[available$metric == "p"], 0.1)
  expect_equal(available$estimate[available$metric == "d_gender"], -0.1)
  missing_reference <- score_groups(
    mutate(example_ratings, t1 = c(0.2, NA_real_)), "available"
  )
  expect_true(is.na(missing_reference$estimate[missing_reference$metric == "d_gender"]))
  no_gender <- score_groups(mutate(example_ratings, gender = NA))
  expect_true(is.na(no_gender$estimate[no_gender$metric == "d_gender"]))
})

test_that("keys, bounds and permutation checks catch consequential failures", {
  expect_equal(score_groups(example_ratings), score_groups(example_ratings[2:1, ]))
  expect_error(score_groups(bind_rows(example_ratings, example_ratings)))
  expect_error(score_groups(mutate(example_ratings, t1 = -99)))
  two <- bind_rows(example_ratings, mutate(example_ratings, episode_id = "second"))
  expect_equal(nrow(score_groups(two)), 14L)
})

test_that("family dependence and weighting survive uneven event sizes", {
  d <- tibble(
    estimate = c(0, 0, 1, 0), positive = c(FALSE, FALSE, TRUE, FALSE),
    family_id = c("a", "a", "a", "b"), event_id = c("a1", "a1", "a2", "b1")
  )
  expect_equal(pool_scores(d, "pairs")$mean, 0.25)
  expect_equal(pool_scores(d, "equal_family_event")$mean, 0.25)
  expect_equal(pool_scores(filter(d, family_id == "a"), "pairs")$mean, 1 / 3)
  expect_equal(pool_scores(filter(d, family_id == "a"), "equal_family_event")$mean, 0.5)
  expect_true(is.na(pool_scores(d)$lower))
  expect_equal(pool_scores(filter(d, family_id == "a"))$families, 1L)
  expect_equal(pool_scores(d[0, ])$inference, "no eligible pairs")
  many <- tibble(
    family_id = as.character(1:10), event_id = family_id,
    estimate = seq(0.01, 0.1, 0.01), positive = TRUE
  )
  expect_equal(pool_scores(many)$inference, "CR2/Satterthwaite")
  expect_true(is.finite(pool_scores(many)$lower))
})
