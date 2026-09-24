source(testthat::test_path("..", "..", "scripts", "00_functions.R"))

test_that("source poll IDs retain the raw dictionary mapping", {
  dictionary <- read_dp_source("index_dictionary") |>
    distinct(dpnum, poll_id)
  files <- c(
    "03_hom_pol_by_group_issue.csv", "05_attitude_change_by_group_issue.csv",
    paste0("03_dom_", c("gender", "educ", "income", "triple"), "_by_group_issue.csv")
  )
  for (file in files) {
    pairs <- read.csv(testthat::test_path("..", "..", "tabs", file))
    expected <- dictionary$poll_id[match(pairs$poll_id, dictionary$dpnum)]
    expect_equal(pairs$source_poll_id, expected, info = file)
  }
})

test_that("combined-share regression uses the outcome's eligible respondents", {
  participants <- read_dp_source("participant_data") |>
    distinct(across(-X), .keep_all = TRUE) |>
    mutate(advantaged = highinc == 1 & bettered == 1 & female == 0) |>
    filter(!is.na(hhincome), !is.na(advantaged)) |>
    summarise(disadvantaged_share = mean(!advantaged), .by = c(dpnum, pollgroup))
  pairs <- read.csv(testthat::test_path(
    "..", "..", "tabs", "03_dom_triple_by_group_issue.csv"
  )) |>
    select(poll_id, group_id, ext_grp) |>
    left_join(participants, by = c("poll_id" = "dpnum", "group_id" = "pollgroup"))
  expected <- lm(ext_grp ~ disadvantaged_share, data = pairs)
  actual <- read.csv(testthat::test_path(
    "..", "..", "tabs", "07_parsing_domination.csv"
  )) |>
    filter(dimension == "triple", outcome == "ext_grp")
  expect_equal(actual$slope, unname(coef(expected)[2]), tolerance = 1e-12)
  expect_equal(actual$intercept, unname(coef(expected)[1]), tolerance = 1e-12)
})

test_that("paired respondents satisfy the subgroup decomposition", {
  for (dimension in c("gender", "educ", "income", "triple")) {
    pairs <- read.csv(testthat::test_path(
      "..", "..", "tabs", paste0("03_dom_", dimension, "_by_group_issue.csv")
    )) |>
      filter(complete.cases(ext_grp_paired, ext_dis_paired, ext_adv_paired))
    decomposition <- with(pairs,
      disadvantaged_share_paired * ext_dis_paired +
        (1 - disadvantaged_share_paired) * ext_adv_paired
    )
    expect_equal(pairs$ext_grp_paired, decomposition, tolerance = 1e-10)
  }
})

test_that("paired and frequency sensitivities retain their stated samples", {
  paired <- read.csv(testthat::test_path(
    "..", "..", "tabs", "09_paired_response_sensitivity.csv"
  )) |>
    filter(sample == "paired")
  measures <- c("D_gender", "D_educ", "D_income", "D_triple")
  expect_equal(paired$n_pairs[match(measures, paired$measure)], c(2433, 2383, 1135, 972))
  frequencies <- read.csv(testthat::test_path(
    "..", "..", "tabs", "09_frequency_comparison.csv"
  ))
  expect_equal(with(frequencies, positive + unchanged + negative), rep(1, nrow(frequencies)))
  expect_equal(frequencies$positive_minus_negative, frequencies$positive - frequencies$negative)
  education <- filter(frequencies, measure == "D_educ")
  expect_equal(education$p_majority, .196173370360819, tolerance = 1e-10)
  expect_equal(education$p_parity, .005451218, tolerance = 1e-8)
})
