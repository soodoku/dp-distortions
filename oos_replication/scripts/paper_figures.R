source("scripts/00_functions.R")
library(ggplot2)

events <- readr::read_csv("oos_replication/events.csv",
  show_col_types = FALSE,
  col_types = readr::cols(.default = readr::col_character())
)
scores <- readRDS("oos_replication/data/group_results.rds") |>
  select(-any_of(c("study_id", "study_label", "panel_label", "mode"))) |>
  left_join(events |> select(event_id, study_id, study_label, panel_label, mode),
    by = "event_id", relationship = "many-to-one"
  ) |>
  filter(!is.na(estimate))
results <- readr::read_csv("oos_replication/tabs/paper_estimates.csv", show_col_types = FALSE)
metric_labels <- c(
  h = "Homogenization", p = "Directional polarization",
  d_gender = "Domination: gender", d_education = "Domination: education",
  d_income = "Domination: income", d_combined = "Domination: combined"
)
fig_theme <- theme_bw() + theme(
  axis.text = element_text(size = 8), axis.ticks = element_blank(),
  panel.grid.major.x = element_line(color = "#eeeeee"),
  panel.grid.major.y = element_line(color = "#dddddd", linetype = "dotted"),
  panel.grid.minor = element_blank(), panel.border = element_blank(),
  strip.background = element_blank(), strip.text = element_text(size = 9),
  plot.margin = unit(rep(.5, 4), "cm"), legend.title = element_blank()
)
dir.create("oos_replication/figs", showWarnings = FALSE)
manifest <- list()

for (scope in c("dp", "extension")) {
  d <- scores |>
    filter(
      construct == "policy", metric %in% names(metric_labels),
      membership == if (scope == "dp") "available" else "paired",
      if (scope == "dp") format == "deliberative_poll" else format != "deliberative_poll"
    ) |>
    mutate(metric = factor(metric, levels = names(metric_labels), labels = metric_labels))
  p <- ggplot(d, aes(estimate)) +
    geom_histogram(aes(y = after_stat(density)),
      bins = 40,
      fill = "grey75", color = "white", linewidth = .2
    ) +
    geom_vline(xintercept = 0, linewidth = .35) +
    facet_wrap(vars(metric), ncol = 2, drop = FALSE) +
    labs(x = "Change on the 0-1 attitude scale", y = "Density") +
    fig_theme
  if (scope == "dp") {
    # Keep the three DP studies separate instead of allowing Climate's items to dominate.
    p <- ggplot(d, aes(estimate)) +
      geom_histogram(aes(y = after_stat(density)),
        bins = 40,
        fill = "grey75", color = "white", linewidth = .2
      ) +
      geom_vline(xintercept = 0, linewidth = .35) +
      facet_grid(study_label ~ metric, drop = FALSE) +
      labs(x = "Change on the 0-1 attitude scale", y = "Density") +
      fig_theme +
      theme(strip.text.x = element_text(size = 7), strip.text.y = element_text(size = 8))
    ggsave("oos_replication/figs/dp_distributions.pdf", p, width = 10.5, height = 5.8)
  } else {
    p <- ggplot(d, aes(panel_label, estimate)) +
      geom_boxplot(linewidth = .3, outlier.size = .6) +
      geom_hline(yintercept = 0, linewidth = .35) +
      coord_flip() +
      facet_wrap(vars(metric), ncol = 2) +
      labs(x = NULL, y = "Change on the 0-1 attitude scale") +
      fig_theme
    ggsave("oos_replication/figs/extension_distributions.pdf", p, width = 9, height = 10)
  }
  manifest[[scope]] <- d |>
    count(study_label, panel_label, metric, name = "pairs") |>
    mutate(figure = if (scope == "dp") "dp_distributions.pdf" else "extension_distributions.pdf")
}

for (domain in unique(results$construct)) {
  d <- results |>
    filter(
      membership == "paired", construct == domain, metric %in% names(metric_labels), pairs > 0,
      if (domain == "policy") format != "deliberative_poll" else TRUE
    ) |>
    mutate(
      metric = factor(metric, levels = names(metric_labels), labels = metric_labels),
      panel_label = factor(panel_label, levels = rev(unique(panel_label)))
    )
  if (nrow(d) == 0) next
  p <- ggplot(d, aes(mean, panel_label)) +
    geom_vline(xintercept = 0, linewidth = .35) +
    geom_point(size = 1.6) +
    facet_wrap(vars(metric), ncol = 2, drop = FALSE) +
    labs(x = "Mean change on the 0-1 attitude scale", y = NULL) +
    fig_theme
  benchmark <- filter(d, study_id == "original")
  if (nrow(benchmark) > 0) {
    p <- p + geom_vline(
      data = benchmark, aes(xintercept = mean),
      linetype = "dashed", color = "grey45", linewidth = .3
    )
  }
  name <- paste0("means_", domain, ".pdf")
  ggsave(file.path("oos_replication/figs", name), p,
    width = 8.8, height = if (domain == "policy") 10 else 6
  )
  manifest[[name]] <- d |>
    select(panel_label, metric, pairs) |>
    mutate(figure = name)
}

polar <- results |>
  filter(
    membership == "paired", construct == "policy", metric %in% c("p", "p_absolute"), pairs > 0
  ) |>
  mutate(
    panel_label = factor(panel_label, levels = rev(unique(panel_label))),
    definition = if_else(metric == "p", "Directional", "Absolute distance")
  )
p <- ggplot(polar, aes(mean, panel_label, shape = definition)) +
  geom_vline(xintercept = 0, linewidth = .35) +
  geom_point(position = position_dodge(width = .4), size = 2) +
  scale_shape_manual(values = c(1, 16)) +
  labs(x = "Mean polarization on the 0-1 attitude scale", y = NULL) +
  fig_theme +
  theme(legend.position = "bottom")
ggsave("oos_replication/figs/polarization_definitions.pdf", p, width = 7, height = 6.8)
manifest[["polarization_definitions"]] <- polar |>
  select(panel_label, metric, pairs) |>
  mutate(figure = "polarization_definitions.pdf")

for (split in c("mode", "region")) {
  d <- scores |>
    filter(membership == "paired", construct == "policy", metric %in% names(metric_labels)) |>
    mutate(
      region = if_else(country %in% c("United States", "United Kingdom"),
        "US / UK", "Other countries"
      ),
      metric = factor(metric, levels = names(metric_labels), labels = metric_labels),
      split_label = .data[[split]]
    )
  p <- ggplot(d, aes(split_label, estimate)) +
    geom_boxplot(linewidth = .3, outlier.size = .5) +
    geom_hline(yintercept = 0, linewidth = .35) +
    coord_flip() +
    facet_wrap(vars(metric), ncol = 2) +
    labs(x = NULL, y = "Change on the 0-1 attitude scale") +
    fig_theme
  name <- paste0("distributions_", split, ".pdf")
  ggsave(file.path("oos_replication/figs", name), p, width = 7, height = 6.5)
  manifest[[name]] <- d |>
    count(split_label, metric, name = "pairs") |>
    mutate(figure = name)
}
readr::write_csv(bind_rows(manifest), "oos_replication/figs/figure_manifest.csv")
