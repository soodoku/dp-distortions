# Input: one row per participant, group, item, and deliberative episode.
score_groups <- function(data, membership = c("paired", "available")) {
  membership <- match.arg(membership)
  key <- c("event_id", "episode_id", "group_id", "item_id", "participant_id")
  stopifnot(
    !anyDuplicated(data[key]), !anyNA(data[key]),
    all(is.na(data$t1) | between(data$t1, 0, 1)),
    all(is.na(data$t2) | between(data$t2, 0, 1))
  )
  data <- data |>
    arrange(across(all_of(key))) |>
    mutate(paired = !is.na(t1) & !is.na(t2))
  if (membership == "paired") {
    data <- data |> mutate(across(c(t1, t2), \(x) if_else(paired, x, NA_real_)))
  }

  group_keys <- c("event_id", "episode_id", "group_id", "item_id", "construct", "midpoint")
  hp <- data |>
    summarise(
      n_pre = sum(!is.na(t1)), n_post = sum(!is.na(t2)),
      n_paired = sum(paired),
      mean_pre = na_if(mean(t1, na.rm = TRUE), NaN),
      mean_post = na_if(mean(t2, na.rm = TRUE), NaN),
      sd_pre = sd(t1, na.rm = TRUE), sd_post = sd(t2, na.rm = TRUE),
      .by = all_of(group_keys)
    ) |>
    mutate(
      h = sd_pre - sd_post,
      p = -signed_move(mean_pre, mean_post, midpoint),
      p_absolute = abs(mean_post - midpoint) - abs(mean_pre - midpoint)
    ) |>
    pivot_longer(c(h, p, p_absolute), names_to = "metric", values_to = "estimate") |>
    select(all_of(group_keys), metric, estimate, n_pre, n_post, n_paired)

  domination <- data |>
    pivot_longer(c(gender, education, income, combined),
      names_to = "dimension", values_to = "advantaged"
    ) |>
    filter(!is.na(advantaged)) |>
    group_by(event_id, episode_id, item_id, construct, midpoint, dimension) |>
    group_modify(\(d, keys) {
      counts <- d |>
        summarise(
          n_pre = sum(!is.na(t1)), n_post = sum(!is.na(t2)),
          n_paired = sum(paired),
          .by = group_id
        )
      means <- dom_pairs_index(mutate(d, pollgroup = group_id), "t1", "t2", d$advantaged)
      if (is.null(means)) {
        return(counts |> mutate(estimate = NA_real_))
      }
      means |>
        select(group_id, estimate = ext_grp) |>
        right_join(counts, by = "group_id", relationship = "one-to-one")
    }) |>
    ungroup()

  if (nrow(domination) > 0) {
    domination <- domination |> mutate(metric = paste0("d_", dimension)) |> select(-dimension)
  } else {
    domination <- hp[0, ]
  }
  domination <- hp |>
    distinct(across(all_of(group_keys))) |>
    cross_join(tibble(metric = paste0("d_", c("gender", "education", "income", "combined")))) |>
    left_join(domination, by = c(group_keys, "metric"), relationship = "one-to-one") |>
    mutate(across(c(n_pre, n_post, n_paired), \(x) coalesce(x, 0L)))
  bind_rows(hp, domination) |>
    mutate(membership = membership, positive = movement_frequency(estimate)) |>
    arrange(event_id, episode_id, group_id, item_id, metric)
}
pool_scores <- function(data, weighting = c("pairs", "equal_family_event")) {
  weighting <- match.arg(weighting)
  data <- data |> filter(!is.na(estimate))
  if (nrow(data) == 0) {
    return(tibble(
      weighting = weighting, pairs = 0L, families = 0L, mean = NA_real_,
      positive_fraction = NA_real_, largest_family_share = NA_real_,
      se = NA_real_, df = NA_real_, lower = NA_real_, upper = NA_real_,
      inference = "no eligible pairs"
    ))
  }
  data <- data |>
    mutate(event_pairs = n(), .by = c(family_id, event_id)) |>
    mutate(family_events = n_distinct(event_id), .by = family_id) |>
    mutate(weight = if (weighting == "pairs") 1 else 1 / (event_pairs * family_events))
  shares <- data |> summarise(weight = sum(weight), .by = family_id)
  result <- tibble(
    weighting = weighting, pairs = nrow(data), families = nrow(shares),
    mean = weighted.mean(data$estimate, data$weight),
    positive_fraction = weighted.mean(data$positive, data$weight),
    largest_family_share = max(shares$weight) / sum(shares$weight),
    se = NA_real_, df = NA_real_, lower = NA_real_, upper = NA_real_,
    inference = "fewer than two independent families"
  )
  if (nrow(shares) < 2) {
    return(result)
  }
  fit <- lm(estimate ~ 1, data = data, weights = weight)
  interval <- tryCatch(
    clubSandwich::conf_int(fit, vcov = "CR2", cluster = data$family_id,
      test = "Satterthwaite", p_values = FALSE
    ),
    error = \(e) NULL
  )
  if (is.null(interval) || !all(is.finite(unlist(interval[c("SE", "df")])))) {
    return(mutate(result, inference = "non-estimable CR2 covariance"))
  }
  result <- result |> mutate(se = interval$SE, df = interval$df)
  if (interval$df < 4) {
    return(mutate(result, inference = "effective df below four"))
  }
  result |>
    mutate(lower = interval$CI_L, upper = interval$CI_U, inference = "CR2/Satterthwaite")
}
