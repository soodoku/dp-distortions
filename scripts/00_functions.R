"
Deliberative Distortions
Shared functions
"

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
})

movement_eps <- 1e-12

# Eq. 3: signed movement of an entity from t1 to t2 toward a reference point.
# Positive = toward the reference. A reference equal to the entity's initial
# mean has no direction and is therefore undefined. Genuine no movement has a
# defined direction and scores zero, as required by the paper's D_b definition.
signed_move <- function(t1, t2, ref_t1, eps = movement_eps) {
  gap <- ref_t1 - t1
  move <- t2 - t1
  out <- move * sign(gap)
  out[!is.na(gap) & abs(gap) < eps] <- NA_real_
  out[!is.na(gap) & abs(gap) >= eps & !is.na(move) & abs(move) < eps] <- 0
  out
}

movement_frequency <- function(x, eps = movement_eps) {
  if_else(is.na(x), NA, x > eps)
}

# One row per small group for one poll x attitude index: group, advantaged,
# and disadvantaged subgroup means at t1/t2, plus the four signed movements.
# adv is a logical over smdata rows. Groups without at least one advantaged
# and one disadvantaged member are dropped (as in the original scripts).
dom_pairs_index <- function(smdata, t1var, t2var, adv) {
  means <- tibble(
    group_id = as.character(smdata$pollgroup),
    adv = adv,
    t1 = smdata[[t1var]],
    t2 = smdata[[t2var]]
  ) |>
    summarise(across(c(t1, t2), \(x) na_if(mean(x, na.rm = TRUE), NaN)),
      .by = c(group_id, adv)
    )

  stopifnot(!anyNA(adv))
  both_sides <- means |>
    count(group_id) |>
    filter(n == 2)
  if (nrow(both_sides) == 0) {
    return(NULL)
  }

  grp <- tibble(
    group_id = as.character(smdata$pollgroup),
    advantaged = adv,
    t1 = smdata[[t1var]],
    t2 = smdata[[t2var]]
  ) |>
    summarise(
      across(c(t1, t2), \(x) na_if(mean(x, na.rm = TRUE), NaN)),
      disadvantaged_share = mean(!advantaged),
      n_eligible = n(),
      .by = group_id
    ) |>
    rename(grp_t1 = t1, grp_t2 = t2)

  means |>
    semi_join(both_sides, by = "group_id") |>
    pivot_wider(names_from = adv, values_from = c(t1, t2)) |>
    rename(
      adv_t1 = t1_TRUE, dis_t1 = t1_FALSE,
      adv_t2 = t2_TRUE, dis_t2 = t2_FALSE
    ) |>
    left_join(grp, by = "group_id") |>
    arrange(group_id) |>
    mutate(
      reference_tie = abs(adv_t1 - grp_t1) < movement_eps,
      no_group_movement = abs(grp_t2 - grp_t1) < movement_eps,
      ext_grp = signed_move(grp_t1, grp_t2, adv_t1), # Eq. 3: D
      ext_dis = signed_move(dis_t1, dis_t2, adv_t1), # disadv. toward adv.
      ext_grp_mir = signed_move(grp_t1, grp_t2, dis_t1), # mirror: toward disadv.
      ext_adv_mir = signed_move(adv_t1, adv_t2, dis_t1), # adv. toward disadv.
      ext_adv = -ext_adv_mir # advantaged subgroup, Eq. 4 direction
    )
}

dp_project_root <- function() {
  rprojroot::find_root(rprojroot::has_file("DESCRIPTION"))
}

dp_source_manifest <- function() {
  read.csv(file.path(dp_project_root(), "data", "sources.csv"))
}

dp_source_path <- function(
  name,
  root = Sys.getenv("DP_DATA_ROOT", unset = file.path(dp_project_root(), "..", "dp-data")),
  manifest = dp_source_manifest()
) {
  entry <- manifest[manifest$source == name, ]
  if (nrow(entry) != 1L) stop("Expected one pinned source: ", name)
  path <- file.path(root, entry$path)
  if (!file.exists(path)) stop("Missing upstream source: ", path)
  hash <- digest::digest(path, algo = "sha256", file = TRUE)
  if (is.na(entry$sha256) || !identical(hash, entry$sha256)) {
    stop("Source checksum mismatch: ", name, ". Review changes before updating its pin.")
  }
  path
}

read_dp_source <- function(name) {
  read.delim(dp_source_path(name), check.names = FALSE)
}

load_dp_data <- function() {
  raw <- read_dp_source("participant_data")
  substantive <- setdiff(names(raw), "X")
  duplicate <- duplicated(raw[substantive])
  dpdat <- raw[!duplicate, , drop = FALSE] |>
    mutate(
      participant_id = paste(pollid, caseid, sep = ":"),
      group_key = paste(dpnum, pollgroup, sep = ":")
    )

  att_indices <- read_dp_source("index_dictionary") |>
    mutate(
      issue_id = t1var,
      actual_n_indices = n(),
      .by = dpnum
    )

  stopifnot(
    !anyDuplicated(dpdat$participant_id),
    !anyDuplicated(att_indices$issue_id),
    all(att_indices$n_indices == att_indices$actual_n_indices),
    all(att_indices$t1var %in% names(dpdat)),
    all(att_indices$t2_t3var %in% names(dpdat))
  )

  list(
    dpdat = dpdat,
    att_indices = att_indices,
    duplicate_rows = raw[duplicate, , drop = FALSE],
    raw_n = nrow(raw),
    analysis_n = nrow(dpdat)
  )
}
