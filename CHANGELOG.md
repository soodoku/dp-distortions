# Changelog

## v1.2.0 - 2026-09-23

- Read unchanged historical and OOS inputs from checksum-pinned dp-data sources;
  retain numerical results and stop on missing or changed source files.
- Consolidate the current analysis in `scripts/`, `tabs/`, and `figs/`.
  Preserve the historical replication under `paper-2022`.
- Add an R out-of-sample analysis and standalone working paper with parallel
  tables and figures: 13 studies, 12 public datasets, 11 dependence families,
  and 6,804 participant-study records. Policy and affective outcomes are separate.
- Compare the original polls, new polls, and other discussions using equal-family
  and pair weights; report paired-response and family-omission sensitivities.
  Aggregate changes are small, and the evidence does not establish a causal
  ranking of discussion formats.
- Document source availability and eligibility, including the public São Tomé
  replication files, whose survey responses lack discussion-group linkage.
- Retain the original study's numerical results from v1.1.0. Validate both
  analyses locally and through GitHub Actions.

## v1.1.0 - 2026-09-10

- Preserve raw source-poll IDs alongside analysis IDs.
- Compute disadvantaged shares from the same eligible respondents as domination,
  correcting the combined-share regression while retaining main Tables 2 and 3.
- Remove unused normalized outputs, including H normalization that exceeded its
  intended bounds, and remove unused custom summary helpers.
- Keep poll CR2/Satterthwaite inference primary and wild bootstrap sensitivity.
  Use `clubSandwich::conf_int()` for the primary confidence intervals.
- Add paired-response, directional-frequency, and attitude-weighting comparisons
  with explicit sample and null definitions. Primary samples and weights stay fixed.
- Correct the audit's expansion of WM, subgroup comparison, and treatment of
  documented manuscript choices as errors.
- Restore and load the pinned R environment for local validation. Update renv
  from 1.2.3 to 1.2.4 to resolve its dependency-installation failure; statistical
  package versions stay fixed.
- Pin the existing ragg PNG renderer so the restored environment preserves the
  committed figures' appearance.

## v1.0.0 - 2026-08-18

Initial corrected-analysis release.

- Reconciles the participant, group, policy-index, and group-index-pair universe.
- Corrects Equation 3 direction, undefined reference ties, combined disadvantage
  parsing, and stale policy-index weighting.
- Regenerates corrected tables, figures, inference, attitude-change estimates,
  validation gates, and provenance ledgers.
- Narrows the paper's directional and causal claims to what the selected polls
  support.
