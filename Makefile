DP_DATA_ROOT ?= $(abspath ../dp-data)
export DP_DATA_ROOT

.PHONY: restore analysis audit test lint ci oos oos-check oos-paper

restore:
	Rscript -e 'renv::restore(prompt = FALSE)'

analysis:
	R_USER_CONFIG_DIR=/tmp/distortions-r-config Rscript scripts/run_all.R

audit: analysis
	Rscript scripts/checks.R

test: audit
	Rscript tests/testthat.R

lint:
	Rscript -e 'lints <- c(lintr::lint_dir("scripts"), lintr::lint_dir("tests")); print(lints); quit(status = length(lints))'

ci: lint test

oos:
	Rscript oos_replication/scripts/run_all.R

oos-check: oos-paper
	Rscript oos_replication/scripts/checks.R
	Rscript -e 'lints <- lintr::lint_dir("oos_replication"); print(lints); quit(status = length(lints))'

oos-paper: oos
	Rscript oos_replication/scripts/paper_tables.R
	Rscript oos_replication/scripts/paper_figures.R
	cd oos_replication && latexmk -pdf -interaction=nonstopmode -halt-on-error paper.tex
