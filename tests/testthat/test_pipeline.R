project_path <- function(...) testthat::test_path("..", "..", ...)

source(project_path("scripts", "00_functions.R"))

test_that("all permanent validation gates pass", {
  validation <- read.csv(project_path("tabs", "99_validation.csv"))
  expect_true(nrow(validation) >= 25)
  expect_true(all(validation$passed))
})

test_that("canonical outputs use unique explicit keys", {
  hp <- read.csv(project_path("tabs", "03_hom_pol_by_group_issue.csv"))
  expect_equal(nrow(hp), 2480)
  expect_equal(anyDuplicated(hp[c("poll_id", "group_key", "issue_id")]), 0)

  for (dimension in c("educ", "gender", "income", "triple")) {
    d <- read.csv(project_path(
      "tabs",
      sprintf("03_dom_%s_by_group_issue.csv", dimension)
    ))
    expect_equal(anyDuplicated(d[c("poll_id", "group_key", "issue_id")]), 0)
    expect_equal(
      nrow(anti_join(d, hp, by = c("poll_id", "group_key", "issue_id"))),
      0
    )
  }
})

test_that("undefined directions and genuine zero movement remain distinct", {
  for (dimension in c("educ", "gender", "income", "triple")) {
    d <- read.csv(project_path(
      "tabs",
      sprintf("03_dom_%s_by_group_issue.csv", dimension)
    ))
    expect_identical(is.na(d$freqgrp_grp), is.na(d$ext_grp))
    valid <- !is.na(d$ext_grp)
    expect_equal(d$freqgrp_grp[valid], d$ext_grp[valid] > movement_eps)
    expect_true(all(is.na(d$ext_grp[d$reference_tie])))
    expect_true(any(d$no_group_movement & !d$reference_tie))
  }
})

test_that("published and corrected Table 2 are traceable", {
  comparison <- read.csv(project_path("tabs", "91_audit_comparison.csv"))
  table2 <- read.csv(project_path("tabs", "02_table_2.csv"))
  expect_equal(nrow(comparison), 12)
  expect_equal(nrow(table2), 12)
  expect_true(all(complete.cases(table2[c("estimate", "se", "df", "p")])))
  expect_true(all(table2$p >= 0 & table2$p <= 1))
  expect_true(all(table2$p_wild_cluster >= 0 & table2$p_wild_cluster <= 1))
})

test_that("claim ledger has producers for every corrected numerical claim", {
  claims <- read.csv(project_path("provenance", "claims.csv"))
  values <- read.csv(project_path("provenance", "values.csv"))
  numerical_filter <- claims$status == "corrected" & claims$claim_id != "C008"
  numerical <- claims$claim_id[numerical_filter]
  expect_setequal(intersect(numerical, unique(values$claim_id)), numerical)
  artifacts <- read.csv(project_path("provenance", "artifacts.csv"))
  expect_true(all(artifacts$exists))
})

test_that("all revised R scripts parse", {
  scripts <- list.files(project_path("scripts"), pattern = "[.]R$", full.names = TRUE)
  expect_no_error(lapply(scripts, parse))
})
