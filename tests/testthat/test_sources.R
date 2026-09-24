source(testthat::test_path("..", "..", "scripts", "00_functions.R"))

test_that("historical upstream sources are pinned and retain the full sample", {
  expect_equal(nrow(dp_source_manifest()), 2L)
  expect_equal(nrow(read_dp_source("participant_data")), 6084L)
  expect_equal(nrow(read_dp_source("index_dictionary")), 129L)
  data <- load_dp_data()
  expect_equal(data$analysis_n, 5867L)
  expect_equal(nrow(data$duplicate_rows), 217L)
  expect_equal(n_distinct(data$dpdat$dpnum), 21L)
})

test_that("upstream verification rejects changed, missing and ambiguous sources", {
  root <- tempfile()
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  path <- file.path(root, "input.tab")
  writeLines(c("id\tvalue", "1\t2"), path)
  manifest <- data.frame(
    source = "example", path = "input.tab",
    sha256 = digest::digest(path, algo = "sha256", file = TRUE)
  )
  expect_identical(dp_source_path("example", root, manifest), path)
  expect_error(dp_source_path("unknown", root, manifest), "one pinned source")
  expect_error(dp_source_path("example", root, manifest[c(1, 1), ]), "one pinned source")
  writeLines(c("id\tvalue", "1\t3"), path)
  expect_error(dp_source_path("example", root, manifest), "checksum mismatch")
  unlink(path)
  expect_error(dp_source_path("example", root, manifest), "Missing upstream")
})


test_that("all OOS inputs resolve upstream and match the central catalog", {
  manifest <- oos_source_manifest()
  expect_equal(nrow(manifest), 24L)
  expect_equal(anyDuplicated(manifest$file), 0L)
  paths <- vapply(manifest$file, oos_source_path, character(1))
  expect_true(all(file.exists(paths)))
  root <- Sys.getenv("DP_DATA_ROOT", unset = file.path(dp_project_root(), "..", "dp-data"))
  catalog <- read.csv(file.path(root, "metadata", "oos_sources.csv"))
  position <- match(manifest$file, catalog$file)
  expect_false(anyNA(position))
  expect_identical(manifest$path, catalog$path[position])
  expect_identical(manifest$sha256, catalog$sha256[position])
})
