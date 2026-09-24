## Replication Data and Scripts for Deliberative Distortions

Paper: [BJPS article](https://doi.org/10.1017/S0007123421000168);
[preprint](http://gsood.com/research/papers/DeliberativeDistortions.pdf).

### Versions

The [`paper-2022` tag](https://github.com/soodoku/distortions/tree/paper-2022)
preserves the historical replication at commit `497d2ae`. Its scripts, tables,
figures, and data are identical to the original files preserved through v1.1.0.
The audit documents discrepancies between those files and some published statements.

The working tree contains the current analysis: `scripts/` writes tables to
`tabs/` and figures to `figs/`. Earlier versions remain available through Git;
there is one set of current scripts and outputs.

### Analysis

The current analysis implements Equation 3 consistently, uses valid group-issue
pairs in aggregation, and removes 217 duplicated participant records. It analyzes
5,867 retained records, 397 groups, 129 policy indices, and 2,480 group-issue pairs.
[AUDIT.md](AUDIT.md) reports numerical changes, their interpretation, and the
consequences of alternative sample and weighting choices.

Poll-clustered CR2 with Satterthwaite inference is primary. Available responses at
each wave remain the primary sample. The
[paired-response comparison](tabs/09_paired_response_sensitivity.csv),
[frequency comparisons](tabs/09_frequency_comparison.csv), and
[attitude-change weights](tabs/05_attitude_change_weighting.csv) report alternatives.

### Reproduction

Dependencies are declared in [DESCRIPTION](DESCRIPTION) and pinned in
[renv.lock](renv.lock) for R 4.6.0. From the repository root:

```sh
git clone --branch v0.2.3 --depth 1 https://github.com/soodoku/dp-data.git ../dp-data
make restore
make ci
```

The two historical inputs now come from dp-data. A release archive extracted to
`../dp-data` also works; set `DP_DATA_ROOT` for another location.
[data/sources.csv](data/sources.csv) pins their commit and SHA-256 checksums.
Missing or changed inputs stop the build. This migration preserves the historical
values and current analysis rules; reconstructed respondent measures are not yet
substituted.

`make ci` runs local linting, the analysis, audit checks, and tests.
GitHub Actions runs these checks and the OOS manuscript build. To regenerate only the analysis, run
`make analysis` or `Rscript scripts/run_all.R`.

To check the audit comparisons against the saved outputs:

```sh
Rscript scripts/checks.R
```

This single audit script verifies the main published-versus-current comparison
and provenance coverage, then computes the missing-mean, reference-tie,
duplicate-record, aggregation, and combined-predictor comparisons. It reuses the
analysis definitions and reads historical poll summaries from `paper-2022` using
Git. Run `git fetch --tags` first if that tag is missing from your clone.

The R commands use the project library through `.Rprofile`. Run `make restore`
once to install the locked dependencies; `--vanilla` bypasses that library.

### Files

The [out-of-sample replication and extension](oos_replication/README.md) studies
previously unused Deliberative Polls and other discussion formats. Its
[results](oos_replication/tabs/results.md) are separate from the article's tables.
The [standalone OOS study](oos_replication/paper.pdf) provides parallel tables and
figures and a separate write-up comparing Deliberative Polls with other discussion
designs. Run `make oos-paper` to build it; this also requires `latexmk` and LaTeX.
Run `make oos-check` after `make restore` to read the pinned dp-data sources and
reproduce and validate those estimates. The
[source register](oos_replication/source_register.csv) records included studies,
exclusions, access gaps, and candidates still being screened.

- [scripts/run_all.R](scripts/run_all.R): analysis entry point.
- [scripts/checks.R](scripts/checks.R): audit entry point.
- [tabs/02_table_2.csv](tabs/02_table_2.csv) and
  [tabs/03_table_3.csv](tabs/03_table_3.csv): current main results.
- [figs/figure_manifest.csv](figs/figure_manifest.csv): figure sources and outputs.
- [data/sources.csv](data/sources.csv): upstream historical responses and index dictionary pins.
- [provenance/](provenance/): claims, numerical values, sources, and checks.

The session information below records the historical published run.

### SessionInfo

```
R version 3.6.3 (2020-02-29)
Platform: x86_64-w64-mingw32/x64 (64-bit)
Running under: Windows 10 x64 (build 18362)

Matrix products: default

locale:
[1] LC_COLLATE=English_United States.1252  LC_CTYPE=English_United States.1252    LC_MONETARY=English_United States.1252
[4] LC_NUMERIC=C                           LC_TIME=English_United States.1252    

attached base packages:
[1] grid      stats     graphics  grDevices utils     datasets  methods   base     

other attached packages:
 [1] forcats_0.5.0   stringr_1.4.0   purrr_0.3.4     readr_1.3.1     tidyr_1.0.2     tibble_3.0.1    tidyverse_1.3.0
 [8] dplyr_0.8.5     ggplot2_3.3.0   rmeta_3.0       lme4_1.1-23     Matrix_1.2-18   goji_0.1.2     

loaded via a namespace (and not attached):
 [1] statmod_1.4.34   tidyselect_1.0.0 splines_3.6.3    haven_2.2.0      lattice_0.20-41  colorspace_1.4-1 vctrs_0.2.4     
 [8] generics_0.0.2   rlang_0.4.5      nloptr_1.2.2.1   pillar_1.4.3     glue_1.4.0       withr_2.1.2      DBI_1.1.0       
[15] dbplyr_1.4.3     modelr_0.1.6     readxl_1.3.1     lifecycle_0.2.0  plyr_1.8.6       munsell_0.5.0    gtable_0.3.0    
[22] cellranger_1.1.0 rvest_0.3.5      labeling_0.3     fansi_0.4.1      broom_0.5.5      Rcpp_1.0.4.6     scales_1.1.0    
[29] backports_1.1.6  jsonlite_1.6.1   farver_2.0.3     fs_1.4.1         hms_0.5.3        digest_0.6.25    stringi_1.4.6   
[36] cli_2.0.2        tools_3.6.3      magrittr_1.5     crayon_1.3.4     pkgconfig_2.0.3  MASS_7.3-51.5    ellipsis_0.3.0  
[43] xml2_1.3.1       reprex_0.3.0     lubridate_1.7.8  rstudioapi_0.11  assertthat_0.2.1 minqa_1.2.4      httr_1.4.1      
[50] R6_2.4.1         boot_1.3-24      nlme_3.1-147     compiler_3.6.3 
```

### Authors

Robert Luskin, Gaurav Sood, James Fishkin, Kyu Hahn
