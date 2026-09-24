"
Deliberative Distortions
Run everything. From the repo root: Rscript scripts/run_all.R
"

dir.create("tabs", showWarnings = FALSE)

source("scripts/00_inventory.R")
source("scripts/01_hom_pol.R")
source("scripts/02_domination.R")
source("scripts/03_se.R")
source("scripts/04_corr_parsing.R")
source("scripts/05_attitude_change.R")
source("scripts/09_sensitivity.R")
source("scripts/06_figs.R")
source("scripts/07_validate.R")
source("scripts/08_provenance.R")
