source(testthat::test_path("..", "..", "scripts", "00_functions.R"))

test_that("canonical eligibility preserves identities and does not create unknown groups", {
  data <- load_dp_data()
  expect_equal(data$raw_n, 5869L)
  expect_equal(data$analysis_n, 5824L)
  expect_equal(n_distinct(data$dpdat$dpnum), 21L)
  expect_true(all(data$dpdat$participant))
  expect_false(anyNA(data$dpdat$pollgroup))
  expect_identical(data$dpdat$pollgroup, data$dpdat$canonical_group)
  expect_false(anyDuplicated(data$dpdat$participant_id) > 0L)
  expect_equal(nrow(data$att_indices), 129L)
  corrected <- load_dp_data("corrected")$dpdat
  exclusions <- corrected |>
    filter(!(participant %in% TRUE)) |>
    count(upstream_poll_id)
  expect_equal(sum(exclusions$n), 41L)
  expect_equal(exclusions$n[exclusions$upstream_poll_id == "nic-1996"], 10L)
  expect_equal(exclusions$n[exclusions$upstream_poll_id == "tomorrows-europe-2007"], 12L)
  expect_equal(exclusions$n[exclusions$upstream_poll_id == "uk-eu-1995"], 14L)
  expect_equal(exclusions$n[exclusions$upstream_poll_id == "san-mateo-2008"], 1L)
})

test_that("both waves come directly from unique primary upstream measure definitions", {
  data <- load_dp_data()
  mapping <- data$definition_mapping
  expect_equal(nrow(mapping), 258L)
  expect_false(any(grepl("midpoint_imputed", mapping$measure_id)))
  measures <- read_dp_source("respondent_measures")
  for (i in seq_len(nrow(mapping))) {
    entry <- mapping[i, ]
    people <- filter(data$dpdat, upstream_poll_id == entry$upstream_poll_id)
    expected <- measures |>
      filter(
        poll_id == entry$upstream_poll_id,
        definition_id == entry$canonical_definition
      ) |>
      select(respondent_id, value_numeric)
    position <- match(people$respondent_id, expected$respondent_id)
    expect_false(anyNA(position), info = entry$legacy_field)
    expect_identical(people[[entry$legacy_field]], expected$value_numeric[position],
      info = entry$legacy_field
    )
  }
  expect_identical(data$dpdat$bettered, as.numeric(data$dpdat$education_above_median))
  expect_identical(data$dpdat$highinc, as.numeric(data$dpdat$income_above_median))
})

test_that("switching primary definitions preserves the cohort and unrelated responses", {
  imputed <- load_dp_data("participants")
  plain <- load_dp_data("plain")
  expect_identical(imputed$dpdat$participant_id, plain$dpdat$participant_id)
  replacements <- imputed$definition_mapping |>
    filter(grepl("_midpoint_imputed$", measure_id))
  expect_equal(nrow(replacements), 46L)
  unchanged <- setdiff(imputed$definition_mapping$legacy_field, replacements$legacy_field)
  expect_equal(imputed$dpdat[unchanged], plain$dpdat[unchanged], tolerance = 1e-12)
  baseline <- imputed$dpdat$chi.t1att1
  observed <- plain$dpdat$chi.t1att1
  expect_equal(sum(!is.na(baseline) & is.na(observed)), 56L)
  expect_true(all(baseline[!is.na(baseline) & is.na(observed)] == .5))
})
