# These stages isolate source corrections, eligibility, missingness, and subgroup definitions.
dp_input_stages <- c("historical", "corrected", "participants", "plain", "primary")

load_dp_data <- function(stage = getOption("dp.input_stage", "primary")) {
  stage <- match.arg(stage, dp_input_stages)
  if (stage == "historical") {
    return(load_historical_data())
  }
  raw <- read_dp_source("corrected_participant_data")
  polls <- read_dp_source("respondent_sources") |>
    select(dpnum, upstream_poll_id = poll_id)
  people <- read_dp_source("analysis_participants") |>
    filter(source_dataset == "historical") |>
    transmute(
      upstream_poll_id = poll_id, respondent_id,
      caseid = as.numeric(historical_respondent_id),
      participant, exclusion_reason, canonical_group = small_group_id,
      education_above_median, income_above_median
    )
  dpdat <- raw |>
    left_join(polls, by = "dpnum", relationship = "many-to-one") |>
    left_join(people, by = c("upstream_poll_id", "caseid"), relationship = "one-to-one")
  stopifnot(!anyNA(dpdat$respondent_id))
  if (stage != "corrected") {
    dpdat <- filter(dpdat, participant %in% TRUE)
  }
  # An unknown discussion group cannot become a synthetic group of unknown people.
  dpdat <- dpdat |>
    filter(!is.na(canonical_group)) |>
    mutate(
      pollgroup = canonical_group,
      participant_id = paste(upstream_poll_id, respondent_id, sep = ":"),
      group_key = paste(dpnum, pollgroup, sep = ":")
    )
  indices <- read_dp_source("corrected_index_dictionary") |>
    mutate(issue_id = t1var, actual_n_indices = n(), .by = dpnum)
  mapping <- indices |>
    left_join(polls, by = "dpnum", relationship = "many-to-one") |>
    select(upstream_poll_id, t1var, t2_t3var) |>
    pivot_longer(c(t1var, t2_t3var), names_to = "wave", values_to = "legacy_field") |>
    left_join(
      read_dp_source("polardata_targets") |>
        select(upstream_poll_id = poll_id, legacy_field, canonical_definition),
      by = c("upstream_poll_id", "legacy_field"), relationship = "one-to-one"
    ) |>
    left_join(
      read_dp_source("measure_definitions") |>
        select(upstream_poll_id = poll_id, canonical_definition = definition_id, measure_id),
      by = c("upstream_poll_id", "canonical_definition"), relationship = "many-to-one"
    )
  stopifnot(!anyNA(mapping$measure_id))
  if (stage %in% c("plain", "primary")) {
    mapping <- mapping |>
      mutate(measure_id = sub("_midpoint_imputed$", "", measure_id)) |>
      select(-canonical_definition) |>
      left_join(
        read_dp_source("measure_definitions") |>
          select(upstream_poll_id = poll_id, measure_id, canonical_definition = definition_id),
        by = c("upstream_poll_id", "measure_id"), relationship = "one-to-one"
      )
    stopifnot(!anyNA(mapping$canonical_definition))
    values <- read_dp_source("respondent_measures") |>
      inner_join(mapping,
        by = c("poll_id" = "upstream_poll_id", "definition_id" = "canonical_definition"),
        relationship = "many-to-one"
      ) |>
      select(upstream_poll_id = poll_id, respondent_id, legacy_field, value_numeric)
    for (field in unique(mapping$legacy_field)) {
      field_values <- filter(values, legacy_field == field)
      joined <- dpdat |>
        select(upstream_poll_id, respondent_id) |>
        left_join(field_values,
          by = c("upstream_poll_id", "respondent_id"), relationship = "one-to-one"
        )
      dpdat[[field]] <- joined$value_numeric
    }
    catalog <- read_dp_source("analysis_attitudes")
    baseline <- filter(mapping, wave == "t1var")
    # The paired adapter must choose exactly the upstream primary baseline definition.
    primary <- catalog |>
      filter(is_primary) |>
      select(upstream_poll_id = poll_id, source_column)
    primary_keys <- paste(primary$upstream_poll_id, primary$source_column)
    stopifnot(all(
      paste(baseline$upstream_poll_id, baseline$measure_id) %in% primary_keys |
        paste(baseline$upstream_poll_id, baseline$legacy_field) %in% primary_keys
    ))
  }
  if (stage == "primary") {
    dpdat <- mutate(dpdat,
      bettered = as.numeric(education_above_median),
      highinc = as.numeric(income_above_median)
    )
  }
  stopifnot(
    !anyDuplicated(dpdat$participant_id), !anyNA(dpdat$pollgroup),
    !anyDuplicated(indices$issue_id), all(indices$n_indices == indices$actual_n_indices),
    all(c(indices$t1var, indices$t2_t3var) %in% names(dpdat))
  )
  list(
    dpdat = dpdat, att_indices = indices,
    duplicate_rows = raw[FALSE, ], raw_n = nrow(raw), analysis_n = nrow(dpdat),
    stage = stage, definition_mapping = mapping
  )
}
