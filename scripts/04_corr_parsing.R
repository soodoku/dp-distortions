"
Deliberative Distortions
Pairwise correlations and parsing-domination regressions
"

source("scripts/00_functions.R")
suppressPackageStartupMessages({
  library(broom)
  library(clubSandwich)
})

dimensions <- c("educ", "gender", "income", "triple")
key <- c("poll_id", "group_key", "issue_id")

dom_pairs <- dimensions |>
  set_names() |>
  map(\(d) read.csv(sprintf("tabs/03_dom_%s_by_group_issue.csv", d)))

hp <- read.csv("tabs/03_hom_pol_by_group_issue.csv") |>
  select(all_of(key), H = homoex, P = polarex)

pairwise_correlation <- function(x, y, x_name, y_name) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  keep <- complete.cases(x, y)
  value <- cor(x[keep], y[keep])
  tibble(
    x = x_name,
    y = y_name,
    n = sum(keep),
    correlation = value
  )
}

correlations <- list(pairwise_correlation(hp$H, hp$P, "H", "P"))

for (dimension in dimensions) {
  joined <- dom_pairs[[dimension]] |>
    select(all_of(key), D = ext_grp) |>
    left_join(hp, by = key)
  correlations <- append(
    correlations,
    list(
      pairwise_correlation(
        joined$D, joined$H,
        paste0("D_", dimension), "H"
      ),
      pairwise_correlation(
        joined$D, joined$P,
        paste0("D_", dimension), "P"
      )
    )
  )
}

correlations <- list_rbind(correlations)
write.csv(correlations, "tabs/05_corr_hpd.csv", row.names = FALSE)

fit_parsing <- function(dimension, outcome) {
  dom <- dom_pairs[[dimension]] |>
    rename(p_dis = disadvantaged_share) |>
    filter(complete.cases(.data[[outcome]], p_dis, poll_id))
  fit <- lm(reformulate("p_dis", outcome), data = dom)
  test <- coef_test(fit,
    vcov = "CR2", cluster = dom$poll_id,
    test = "Satterthwaite"
  )
  slope_test <- as.data.frame(test) |>
    filter(Coef == "p_dis")
  coefficients <- coef(fit)
  intercept_value <- unname(coefficients["(Intercept)"])
  slope_value <- unname(coefficients["p_dis"])

  tibble(
    dimension = dimension,
    outcome = outcome,
    intercept = intercept_value,
    slope = slope_value,
    slope_se = slope_test$SE,
    slope_df = slope_test$df_Satt,
    slope_p = slope_test$p_Satt,
    prediction_at_20 = unname(coefficients[1] + .2 * coefficients[2]),
    prediction_at_80 = unname(coefficients[1] + .8 * coefficients[2]),
    prediction_at_95 = unname(coefficients[1] + .95 * coefficients[2]),
    n_pairs = nrow(dom),
    n_groups = n_distinct(dom$group_key),
    n_polls = n_distinct(dom$poll_id)
  )
}

fits <- expand_grid(
  dimension = dimensions,
  outcome = c("ext_dis", "ext_grp")
) |>
  pmap(fit_parsing) |>
  list_rbind()

write.csv(fits, "tabs/07_parsing_domination.csv", row.names = FALSE)
