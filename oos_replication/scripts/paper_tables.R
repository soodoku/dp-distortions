source("scripts/00_functions.R")
source("oos_replication/scripts/metrics.R")
options(knitr.kable.NA = "--")

events <- readr::read_csv("oos_replication/events.csv",
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
labels <- events |> select(event_id, study_id, study_label, panel_label, mode)
ratings <- readRDS("oos_replication/data/ratings.rds") |>
  left_join(labels, by = "event_id", relationship = "many-to-one")
scores <- readRDS("oos_replication/data/group_results.rds") |>
  select(-any_of(c("study_id", "study_label", "panel_label", "mode"))) |>
  left_join(labels, by = "event_id", relationship = "many-to-one")
register <- readr::read_csv("oos_replication/source_register.csv",
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)

# The paired denominator makes Equation 4 an exact within-cell decomposition.
components <- ratings |>
  filter(!is.na(t1), !is.na(t2)) |>
  pivot_longer(c(gender, education, income, combined),
    names_to = "dimension", values_to = "advantaged"
  ) |>
  filter(!is.na(advantaged)) |>
  group_by(event_id, episode_id, item_id, construct, dimension) |>
  group_modify(\(d, keys) {
    result <- dom_pairs_index(mutate(d, pollgroup = group_id), "t1", "t2", d$advantaged)
    if (is.null(result)) {
      return(tibble())
    }
    result
  }) |>
  ungroup() |>
  left_join(events, by = "event_id", relationship = "many-to-one")
stopifnot(all(with(
  components,
  is.na(ext_grp) | is.na(ext_dis) | is.na(ext_adv) |
    abs(ext_grp - disadvantaged_share * ext_dis - (1 - disadvantaged_share) * ext_adv) < 1e-12
)))
component_check <- components |>
  transmute(event_id, episode_id, group_id, item_id, metric = paste0("d_", dimension), ext_grp) |>
  full_join(
    scores |>
      filter(membership == "paired", startsWith(metric, "d_")) |>
      select(event_id, episode_id, group_id, item_id, metric, estimate),
    by = c("event_id", "episode_id", "group_id", "item_id", "metric"),
    relationship = "one-to-one"
  )
stopifnot(
  identical(is.na(component_check$ext_grp), is.na(component_check$estimate)),
  all(abs(component_check$ext_grp - component_check$estimate) < 1e-12, na.rm = TRUE)
)
saveRDS(components, "oos_replication/data/domination_components.rds")

original_hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv")
original_scores <- map_dfr(c("paired", "available"), \(sample) {
  suffix <- if (sample == "paired") "_cc" else ""
  original_hp |>
    transmute(
      event_id = as.character(poll_id), group_id = group_key, item_id = issue_id,
      h = .data[[paste0("homoex", suffix)]], p = .data[[paste0("polarex", suffix)]],
      p_absolute = .data[[paste0("polar_abs", suffix)]]
    ) |>
    pivot_longer(c(h, p, p_absolute), names_to = "metric", values_to = "estimate") |>
    mutate(membership = sample)
})
original_components <- map_dfr(c("gender", "educ", "income", "triple"), \(dimension) {
  read.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", dimension)) |>
    mutate(dimension = recode(dimension, educ = "education", triple = "combined"))
})
original_scores <- bind_rows(
  original_scores,
  map_dfr(c("paired", "available"), \(sample) {
    original_components |>
      transmute(
        event_id = as.character(poll_id), group_id = group_key, item_id = issue_id,
        metric = paste0("d_", dimension), membership = sample,
        estimate = if (sample == "paired") ext_grp_paired else ext_grp
      )
  })
) |>
  mutate(
    study_id = "original", study_label = "Corrected original", panel_label = study_label,
    format = "original", construct = "policy", family_id = event_id,
    episode_id = "main", positive = movement_frequency(estimate)
  )
all_scores <- bind_rows(scores, original_scores)
panel_order <- c("Corrected original", unique(events$panel_label))
metric_order <- c("h", "p", "d_gender", "d_education", "d_income", "d_combined", "p_absolute")

main_results <- all_scores |>
  summarise(
    pairs = sum(!is.na(estimate)), mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    zero_fraction = na_if(mean(abs(estimate) <= movement_eps, na.rm = TRUE), NaN),
    mean_absolute = na_if(mean(abs(estimate), na.rm = TRUE), NaN),
    .by = c(study_id, study_label, panel_label, format, construct, membership, metric)
  ) |>
  mutate(panel_label = factor(panel_label, levels = panel_order)) |>
  arrange(panel_label, construct, membership, match(metric, metric_order))
readr::write_csv(main_results, "oos_replication/tabs/paper_estimates.csv")

overall_scores <- all_scores |>
  filter(construct %in% c("policy", "affect"), !is.na(estimate)) |>
  mutate(comparison = case_when(
    study_id == "original" ~ "Original DPs",
    format == "deliberative_poll" ~ "New DPs",
    TRUE ~ "Other group discussions"
  ))
overall_studies <- overall_scores |>
  summarise(
    mean = mean(estimate), pairs = n(), positive_fraction = mean(positive),
    .by = c(comparison, construct, membership, metric, family_id, study_id)
  )
overall_families <- overall_studies |>
  summarise(
    mean = mean(mean), positive_fraction = mean(positive_fraction),
    pairs = sum(pairs), studies = n(),
    .by = c(comparison, construct, membership, metric, family_id)
  )
overall <- overall_families |>
  summarise(
    mean = mean(mean), positive_fraction = mean(positive_fraction),
    pairs = sum(pairs), studies = sum(studies), families = n(),
    .by = c(comparison, construct, membership, metric)
  ) |>
  mutate(weighting = "equal_family_study") |>
  bind_rows(overall_scores |>
    summarise(
      mean = mean(estimate), positive_fraction = mean(positive), pairs = n(),
      studies = n_distinct(family_id, study_id), families = n_distinct(family_id),
      .by = c(comparison, construct, membership, metric)
    ) |>
    mutate(weighting = "pairs")
  )
overall_omissions <- overall_families |>
  group_by(comparison, construct, membership, metric) |>
  mutate(
    remaining_families = n() - 1L,
    mean_without_family = if (n() > 1L) (sum(mean) - mean) / (n() - 1L) else NA_real_
  ) |>
  ungroup()
readr::write_csv(overall, "oos_replication/tabs/paper_overall.csv")
readr::write_csv(overall_families, "oos_replication/tabs/paper_overall_families.csv")
readr::write_csv(overall_omissions, "oos_replication/tabs/paper_overall_omissions.csv")
for (weight in c("equal_family_study", "pairs")) {
  overall_table <- overall |>
    filter(construct == "policy", membership == "paired", weighting == weight) |>
    mutate(
      comparison = factor(comparison, c("Original DPs", "New DPs", "Other group discussions")),
      metric = factor(metric, c(
        "h", "p", "p_absolute", "d_gender", "d_education", "d_income", "d_combined"
      )),
      cell = sprintf("%.2f (%d)", 100 * mean, families)
    ) |>
    select(comparison, metric, cell) |>
    pivot_wider(names_from = metric, values_from = cell, names_sort = TRUE) |>
    arrange(comparison)
  overall_tex <- knitr::kable(overall_table,
    format = "latex", booktabs = TRUE, row.names = FALSE,
    col.names = c(
      "Study set", "H", "Directional P", "Absolute P", "Gender D", "Education D",
      "Income D", "Combined D"
    )
  )
  writeLines(as.character(overall_tex),
    sprintf("oos_replication/tabs/paper_overall_%s.tex", weight)
  )
}

design_comparison <- main_results |>
  filter(
    membership == "paired", construct == "policy",
    panel_label %in% c(
      "Corrected original", "UK: same-party", "UK: mixed-party",
      "Diplomacy: structured", "Diplomacy: unstructured"
    ), metric %in% c("h", "p", "p_absolute", "d_gender")
  ) |>
  mutate(mean = 100 * mean) |>
  select(panel_label, metric, mean, pairs) |>
  pivot_wider(names_from = metric, values_from = c(mean, pairs))
readr::write_csv(design_comparison, "oos_replication/tabs/paper_design_comparison.csv")
design_tex <- knitr::kable(design_comparison |>
    select(panel_label, mean_h, mean_p, mean_p_absolute, mean_d_gender),
  format = "latex", booktabs = TRUE, row.names = FALSE, digits = 2,
  col.names = c("Study / condition", "H", "Directional P", "Absolute P", "Gender D")
)
writeLines(as.character(design_tex), "oos_replication/tabs/paper_design_comparison.tex")

for (view in c("dp", "extension")) {
  primary <- main_results |>
    filter(construct == "policy", metric != "p_absolute",
      if (view == "dp") {
        membership == "available" & format %in% c("original", "deliberative_poll")
      } else {
        membership == "paired" & format != "deliberative_poll"
      }
    ) |>
    mutate(metric = factor(metric, levels = metric_order),
      cell = if_else(pairs == 0, "--", sprintf("%.3f / %.1f", mean, 100 * positive_fraction))
    ) |>
    select(panel_label, metric, cell) |>
    pivot_wider(names_from = metric, values_from = cell, names_sort = TRUE)
  primary_tex <- knitr::kable(primary, format = "latex", booktabs = TRUE,
    col.names = c(
      "Study / condition", "H", "P", "Gender D", "Education D", "Income D", "Combined D"
    ), row.names = FALSE, align = c("l", rep("r", 6))
  )
  writeLines(as.character(primary_tex),
    sprintf("oos_replication/tabs/paper_table_2_%s_primary.tex", view)
  )
}

inventory <- ratings |>
  summarise(
    participants = n_distinct(participant_id),
    group_episodes = n_distinct(event_id, episode_id, group_id),
    items = n_distinct(item_id), policy_items = n_distinct(item_id[construct == "policy"]),
    .by = c(study_id, study_label)
  ) |>
  left_join(events |>
    summarise(
      country = paste(unique(country), collapse = "; "), mode = first(mode),
      year = if (all(is.na(fieldwork_start))) {
        "Unknown"
      } else {
        paste(sort(unique(substr(na.omit(fieldwork_start), 1, 4))), collapse = "; ")
      }, source = first(source), family_id = first(family_id),
      design = if (all(format == "deliberative_poll")) "DP" else "Extension",
      .by = study_id
    ), by = "study_id", relationship = "one-to-one")
readr::write_csv(inventory, "oos_replication/tabs/paper_inventory.csv")
inventory_tex <- knitr::kable(inventory |>
  select(
    Study = study_label, Country = country, Year = year, Mode = mode,
    N = participants, Episodes = group_episodes, Items = items, Policy = policy_items
  ), format = "latex", booktabs = TRUE, row.names = FALSE)
writeLines(as.character(inventory_tex), "oos_replication/tabs/paper_inventory.tex")

for (sample in c("paired", "available")) {
  for (domain in unique(main_results$construct)) {
    table <- main_results |>
      filter(membership == sample, construct == domain, metric != "p_absolute") |>
      mutate(
        metric = factor(metric, levels = metric_order),
        cell = if_else(pairs == 0, "--", sprintf("%.3f / %.1f", mean, 100 * positive_fraction))
      ) |>
      select(panel_label, metric, cell) |>
      pivot_wider(names_from = metric, values_from = cell, names_sort = TRUE) |>
      rename(Study = panel_label)
    if (nrow(table) == 0) next
    table_tex <- knitr::kable(table,
      format = "latex", booktabs = TRUE,
      col.names = c(
        "Study / condition", "H", "P", "Gender D", "Education D", "Income D", "Combined D"
      ),
      row.names = FALSE, align = c("l", rep("r", 6))
    )
    writeLines(as.character(table_tex),
      sprintf("oos_replication/tabs/paper_table_2_%s_%s.tex", domain, sample)
    )
  }
}

component_long <- components |>
  select(
    study_id, study_label, panel_label, format, construct, dimension,
    event_id, episode_id, group_id, item_id, ext_grp, ext_dis, ext_adv
  ) |>
  bind_rows(original_components |>
    transmute(
      study_id = "original", study_label = "Corrected original", panel_label = study_label,
      format = "original", construct = "policy", dimension, event_id = as.character(poll_id),
      episode_id = "main", group_id = group_key, item_id = issue_id,
      ext_grp = ext_grp_paired, ext_dis = ext_dis_paired, ext_adv = ext_adv_paired
    )) |>
  pivot_longer(c(ext_grp, ext_dis, ext_adv), names_to = "component", values_to = "estimate") |>
  mutate(positive = movement_frequency(estimate))
component_results <- component_long |>
  summarise(
    pairs = sum(!is.na(estimate)),
    mean = na_if(mean(estimate, na.rm = TRUE), NaN),
    positive_fraction = na_if(mean(positive, na.rm = TRUE), NaN),
    .by = c(study_id, study_label, panel_label, format, construct, dimension, component)
  ) |>
  mutate(panel_label = factor(panel_label, levels = panel_order)) |>
  arrange(panel_label, dimension, component)
readr::write_csv(component_results, "oos_replication/tabs/paper_components.csv")
for (dimension in c("gender", "education", "income", "combined")) {
  table <- component_results |>
    filter(construct == "policy", .data$dimension == .env$dimension) |>
    mutate(
      component = factor(component, levels = c("ext_grp", "ext_dis", "ext_adv")),
      cell = if_else(pairs == 0, "--",
        sprintf("%.3f / %.1f (%s)", mean, 100 * positive_fraction, pairs)
      )
    ) |>
    select(panel_label, component, cell) |>
    pivot_wider(names_from = component, values_from = cell, names_sort = TRUE)
  table_tex <- knitr::kable(table,
    format = "latex", booktabs = TRUE,
    col.names = c("Study / condition", "Whole group D", "Disadvantaged M", "Advantaged M"),
    row.names = FALSE, align = c("l", "r", "r", "r")
  )
  writeLines(as.character(table_tex),
    sprintf("oos_replication/tabs/paper_table_3_%s.tex", dimension)
  )
}

change_pairs <- ratings |>
  mutate(change = t2 - t1) |>
  summarise(
    net = na_if(abs(mean(change, na.rm = TRUE)), NaN),
    gross = na_if(mean(abs(change), na.rm = TRUE), NaN), n_paired = sum(!is.na(change)),
    .by = c(study_id, study_label, panel_label, event_id, episode_id, group_id, item_id, construct)
  ) |>
  bind_rows(read.csv("tabs/05_attitude_change_by_group_issue.csv") |>
    transmute(
      study_id = "original", study_label = "Corrected original", panel_label = study_label,
      event_id = as.character(poll_id), episode_id = "main", group_id = group_key,
      item_id = issue_id, construct = "policy", net = net_change, gross = gross_change,
      n_paired = n_complete
    ))
change_results <- bind_rows(
  change_pairs |>
    summarise(
      net = mean(net, na.rm = TRUE), gross = mean(gross, na.rm = TRUE),
      pairs = sum(n_paired > 0), .by = c(panel_label, construct)
    ) |>
    mutate(weighting = "Equal group-item episodes"),
  change_pairs |>
    summarise(
      net = mean(net, na.rm = TRUE), gross = mean(gross, na.rm = TRUE),
      .by = c(panel_label, construct, event_id, episode_id, group_id)
    ) |>
    summarise(
      net = mean(net, na.rm = TRUE), gross = mean(gross, na.rm = TRUE),
      .by = c(panel_label, construct)
    ) |>
    mutate(weighting = "Equal group episodes")
) |>
  mutate(panel_label = factor(panel_label, levels = panel_order)) |>
  arrange(panel_label, construct, weighting)
readr::write_csv(change_results, "oos_replication/tabs/paper_attitude_change.csv")
writeLines(as.character(knitr::kable(
  change_results |>
    filter(construct == "policy", weighting == "Equal group-item episodes") |>
    select(Study = panel_label, Net = net, Gross = gross, Pairs = pairs),
  format = "latex", booktabs = TRUE, digits = 3, row.names = FALSE
)), "oos_replication/tabs/paper_attitude_change.tex")

frequency_inference <- scores |>
  mutate(estimate = as.numeric(positive)) |>
  group_by(format, construct, timing_class, membership, metric) |>
  group_modify(\(d, keys) map_dfr(c("pairs", "equal_family_event"), \(w) pool_scores(d, w))) |>
  ungroup()
readr::write_csv(frequency_inference, "oos_replication/tabs/paper_frequency_inference.csv")

correlations <- all_scores |>
  filter(membership == "paired", metric != "p_absolute") |>
  select(panel_label, construct, event_id, episode_id, group_id, item_id, metric, estimate) |>
  pivot_wider(names_from = metric, values_from = estimate) |>
  group_by(panel_label, construct) |>
  group_modify(\(d, keys) {
    comparisons <- tibble(
      x = c("h", rep(c("h", "p"), each = 4)),
      y = c("p", rep(paste0("d_", c("gender", "education", "income", "combined")), 2))
    )
    pmap_dfr(comparisons, \(x, y) {
      observed <- d[complete.cases(d[c(x, y)]), ]
      valid <- nrow(observed) >= 3 && sd(observed[[x]]) > 0 && sd(observed[[y]]) > 0
      tibble(x, y,
        pairs = nrow(observed),
        correlation = if (valid) cor(observed[[x]], observed[[y]]) else NA_real_
      )
    })
  }) |>
  ungroup()
readr::write_csv(correlations, "oos_replication/tabs/paper_correlations.csv")

# Composition predictions are descriptive and only shown within observed support.
composition_results <- components |>
  filter(construct == "policy") |>
  pivot_longer(c(ext_grp, ext_dis), names_to = "outcome", values_to = "movement") |>
  filter(!is.na(movement), !is.na(disadvantaged_share)) |>
  group_by(panel_label, dimension, outcome) |>
  group_modify(\(d, keys) {
    support <- range(d$disadvantaged_share)
    if (nrow(d) < 3 || diff(support) < 1e-12) {
      return(tibble())
    }
    fit <- lm(movement ~ disadvantaged_share, data = d)
    predictions <- predict(fit, newdata = tibble(disadvantaged_share = c(.2, .8)))
    broom::tidy(fit) |>
      filter(term == "disadvantaged_share") |>
      transmute(
        slope = estimate, pairs = nrow(d), minimum_share = support[1], maximum_share = support[2],
        at_20 = if (support[1] <= .2 && support[2] >= .2) predictions[1] else NA_real_,
        at_80 = if (support[1] <= .8 && support[2] >= .8) predictions[2] else NA_real_
      )
  }) |>
  ungroup()
readr::write_csv(composition_results, "oos_replication/tabs/paper_composition.csv")

readr::write_csv(
  main_results |>
    filter(membership == "paired", metric %in% c("p", "p_absolute")) |>
    select(panel_label, construct, metric, pairs, mean) |>
    pivot_wider(names_from = metric, values_from = c(pairs, mean)),
  "oos_replication/tabs/paper_polarization_comparison.csv"
)
writeLines(as.character(knitr::kable(
  main_results |>
    filter(membership == "paired", construct == "policy", metric %in% c("p", "p_absolute")) |>
    select(panel_label, metric, pairs, mean) |>
    pivot_wider(names_from = metric, values_from = c(mean, pairs)),
  format = "latex", booktabs = TRUE, digits = 3,
  col.names = c("Study / condition", "Directional P", "Absolute P", "N directional", "N absolute")
)), "oos_replication/tabs/paper_polarization_comparison.tex")

sample_sizes <- ratings |>
  filter(!is.na(t1), !is.na(t2)) |>
  pivot_longer(c(gender, education, income, combined),
    names_to = "dimension", values_to = "advantaged"
  ) |>
  filter(!is.na(advantaged)) |>
  inner_join(
    components |>
      filter(!is.na(ext_grp)) |>
      select(event_id, episode_id, group_id, item_id, dimension),
    by = c("event_id", "episode_id", "group_id", "item_id", "dimension"),
    relationship = "many-to-one"
  ) |>
  summarise(
    participants = n_distinct(participant_id),
    group_episodes = n_distinct(event_id, episode_id, group_id),
    .by = c(study_id, study_label, construct, dimension)
  )
readr::write_csv(sample_sizes, "oos_replication/tabs/paper_domination_sample.csv")

values <- main_results |>
  mutate(key = paste(
    gsub("[^a-z0-9]", "", tolower(panel_label)), construct, membership, metric, sep = "."
  )) |>
  select(key, value = mean) |>
  bind_rows(
    component_results |>
      transmute(key = paste(
        gsub("[^a-z0-9]", "", tolower(panel_label)), "components",
        construct, dimension, component, sep = "."
      ), value = mean)
  ) |>
  filter(!is.na(value)) |>
  mutate(formatted = sprintf("%.3f", value))
counts <- tibble(
  key = c(
    "studies", "families", "participantrecords", "sources", "screened",
    "dpstudies", "extensionstudies"
  ),
  value = c(
    nrow(inventory), n_distinct(inventory$family_id), sum(inventory$participants),
    n_distinct(inventory$source), nrow(register),
    sum(inventory$design == "DP"), sum(inventory$design != "DP")
  ),
  formatted = format(value, big.mark = ",", scientific = FALSE, trim = TRUE)
)
values <- bind_rows(values, counts, overall |>
  transmute(
    key = paste(
      "overall", gsub("[^a-z0-9]", "", tolower(comparison)), construct, membership, weighting,
      metric, sep = "."
    ), value = mean, formatted = sprintf("%.2f", 100 * mean)
  )
)
values <- bind_rows(values, overall_omissions |>
  filter(construct == "policy", membership == "paired", !is.na(mean_without_family)) |>
  summarise(
    low = min(mean_without_family), high = max(mean_without_family),
    .by = c(comparison, metric)
  ) |>
  pivot_longer(c(low, high), names_to = "endpoint", values_to = "value") |>
  transmute(
    key = paste(
      "omission", gsub("[^a-z0-9]", "", tolower(comparison)), metric, endpoint, sep = "."
    ), value, formatted = sprintf("%.2f", 100 * value)
  ), overall_omissions |>
  filter(membership == "paired", family_id == "hongkong_2020", metric == "h") |>
  transmute(key = "omit_hongkong_h", value = mean_without_family,
    formatted = sprintf("%.2f", 100 * value)
  )
)
stopifnot(!anyDuplicated(values$key))
readr::write_csv(values, "oos_replication/tabs/paper_values.csv")
writeLines(
  sprintf("\\expandafter\\def\\csname value:%s\\endcsname{%s}", values$key, values$formatted),
  "oos_replication/tabs/paper_values.tex"
)

source_table <- inventory |>
  left_join(register |> select(source = url, authors, source_published),
    by = "source", relationship = "many-to-one"
  ) |>
  transmute(
    Study = study_label, Archive = sub("https://doi.org/", "", source),
    Released = substr(source_published, 1, 10)
  )
source_tex <- knitr::kable(source_table,
  format = "latex", booktabs = TRUE, row.names = FALSE
)
writeLines(as.character(source_tex), "oos_replication/tabs/paper_sources.tex")
message("Parallel tables generated; subgroup decomposition matches existing D estimates.")
