# Correction and validation report

## Verdict

Across the observed deliberative polls, average signed homogenization,
directional polarization, and domination are small. The corrected domination
results do not support a general tendency toward opposition. Education points
toward modest domination, while gender and income are near zero. The combined
estimate is positive but sensitive to the small-cluster inference method.

The paper interprets the pattern as compatible with weighing the merits (WM).
It explicitly recognizes that full-consideration attitudes are unobserved and
that the polls and issues were not randomly sampled. Compatibility with that
theory is distinct from identifying its mechanism: the analysis has no untreated
comparison or experimental contrast of deliberative designs. The earlier audit's
expansion of WM as "working memory" was incorrect.

The independent review reproduced the current main estimates and CR2 inference.
The subsequent source-ID and regression-denominator fixes leave Tables 2 and 3
unchanged. Numerical choices below are reported separately from coding defects.

## Analysis universe

The published inventories mix several versions of the data. The corrected
pipeline uses the following explicit universe:

| Quantity | Published descriptions | Corrected value |
|---|---:|---:|
| Participant records | 5,736 or 6,084 | 6,084 raw records |
| Exact duplicate records | Not reported | 217 |
| Retained participant records | Not reported | 5,867 |
| Small groups | 372 or 397 | 397 |
| Policy indices | 134 or 139 | 129 |
| Group-index pairs | 2,601 | 2,480 |

All 217 duplicates occur in the US Presidential Primaries poll. Each duplicate
has the same poll, case identifier, group, covariates, and responses as its
retained record. Removing them does not change any group mean beyond numerical
precision, but it corrects participant counts and sample standard deviations.
One retained record has no case ID; its inclusion is preserved, and the count
does not imply that every participant identity can be independently verified.

The original code uses stale poll-level `numindices` values as weights. The
corrected analysis gives one unit of weight to each valid group-index pair and
records an outcome-specific denominator.

## Corrected Table 2

The point estimate is the mean over actual valid group-index pairs. The primary
standard error uses CR2 clustered by deliberative poll with Satterthwaite
degrees of freedom. The wild-cluster column reports a null-imposed bootstrap
with 99,999 draws. Frequencies are tested against .5; signed means against zero.

| Construct | Estimate | SE | 95% CI | CR2 p | Wild p | N |
|---|---:|---:|---:|---:|---:|---:|
| H | .01285 | .00311 | [.00617, .01953] | .0010 | .0010 | 2,480 |
| Hb | .58589 | .02022 | [.54247, .62930] | .0008 | .0004 | 2,480 |
| P | -.02221 | .00838 | [-.04019, -.00423] | .0191 | .0215 | 2,431 |
| Pb | .43974 | .04068 | [.35245, .52702] | .1608 | .1839 | 2,431 |
| Gender D | .00175 | .00352 | [-.00580, .00931] | .6260 | .6305 | 2,436 |
| Gender Db | .47126 | .01420 | [.44080, .50173] | .0626 | .0636 | 2,436 |
| Education D | .01004 | .00313 | [.00332, .01676] | .0063 | .0009 | 2,385 |
| Education Db | .52327 | .01715 | [.48650, .56004] | .1962 | .1986 | 2,385 |
| Income D | .00151 | .00419 | [-.00829, .01130] | .7292 | .7277 | 1,144 |
| Income Db | .50524 | .01753 | [.46424, .54625] | .7730 | .7647 | 1,144 |
| Combined D | .01285 | .00594 | [-.00100, .02670] | .0646 | .0414 | 983 |
| Combined Db | .51882 | .01528 | [.48317, .55447] | .2553 | .2399 | 983 |

The paper defines `Db = 1` when `D > 0` and `Db = 0` when `D <= 0`.
Accordingly, genuine no-movement cases remain in the denominator as zero.
Cases where the initial group mean equals the initial advantaged mean have no
defined direction under Equation 3 and are excluded rather than recoded zero.

Across the 12 primary tests, Holm correction retains H and Hb. The wild-cluster
Holm correction also retains education D. Benjamini and Hochberg correction for
the CR2 p-values retains H, Hb, and education D. These adjustments do not
support a broad opposition claim.

## Corrected Table 3

`dM` is disadvantaged-member movement toward the advantaged reference. `aM`
uses the same domination direction for advantaged members, so negative values
mean movement toward disadvantaged members. Frequencies use the same signs and
count defined zero movement as false.

| Dimension | D | dM | aM | Db | dMb | aMb |
|---|---:|---:|---:|---:|---:|---:|
| Gender | .00175 | .03947 | -.03665 | .47126 | .57160 | .36192 |
| Education | .01004 | .05224 | -.03011 | .52327 | .59346 | .39045 |
| Income | .00151 | .04899 | -.03256 | .50524 | .56731 | .41259 |
| Combined | .01285 | .02945 | -.06413 | .51882 | .55239 | .30319 |

The subgroup estimates show movement toward one another. The disadvantaged move
farther on gender, education, and income; the advantaged move farther on combined
advantage. This reverses the comparison in the published Table 3 discussion.
These marginal means have outcome-specific denominators. They cannot be plugged
into a fixed-share identity to reproduce the aggregate D exactly.

## Other corrected statements

- The H and P correlation is .4043 over all 2,431 valid common pairs. The
  published .358 conditions on all original domination columns being observed.
  These correlations describe different samples; pairwise deletion is an explicit
  analysis choice.
- The combined disadvantaged share means female or lower education or lower
  income. Predictor and outcome now use the same eligible participants. This
  changes the combined D regression slope from .0000569 to .0043895. Predicted D
  at disadvantaged shares .20/.80/.95 changes from .01282/.01285/.01286 to
  .01021/.01284/.01350. The association remains small; it is not a causal effect
  of changing group composition.
- If two of twenty people move by .1, the group mean moves by .010, not .10.
- Table 2 contains 12 estimates, not ten. Four have unadjusted CR2 p-values
  below .05 under the corrected primary inference.
- H uses the sample standard deviation, which can exceed .5. Unused normalized
  outputs based on a .5 upper bound were removed: 12 normalized H values fell
  below -1 (minimum -3.91235), and four were undefined. Main H/P/D estimates and
  figures retain their existing definitions and scales.
- The paper defines directional P and explicitly discusses midpoint crossings
  in footnote 8. Its definition is retained; this was not a newly discovered
  conceptual error.
- Source poll IDs now preserve the raw dictionary mapping. For example, New
  Haven has source ID 91 and analysis ID 12. The overwritten source field was
  not used for estimating the main results, which therefore do not change.

## Sample, weighting, and null choices

Available responses at each wave remain primary. A paired-response sensitivity
uses the same people at both waves and recomputes the initial reference means.
The resulting means are:

| Measure | Available responses | Paired responses |
|---|---:|---:|
| H | .012849 | .012290 |
| P | -.022211 | -.022366 |
| Gender D | .001754 | .001917 |
| Education D | .010043 | .011074 |
| Income D | .001506 | .002937 |
| Combined D | .012852 | .013983 |

The paper's Eq. 4 decomposition assumes fixed subgroup composition. Different
response sets at each wave need not satisfy it. Paired responses restore the
identity, but select a different sample; they are a sensitivity analysis, not a
correction to the definition of available-wave means. The direct Eq. 3 estimate
remains the primary outcome. The paired file reports poll CR2 intervals and
unadjusted p-values for this separate sample.
Education D has CR2 p=.0063 with available responses and .0061 with paired
responses. Combined D has p=.0646 and .0339, respectively. Its average magnitude
and direction remain similar, while the .05 significance decision changes.

Binary frequencies retain the paper's null of .5 among all defined cases,
including genuine zero movement. Testing whether positive and negative movement
are equally frequent asks a different question. Education has 52.327% positive,
44.654% negative, and 3.019% unchanged movement. Its two-sided poll CR2 p-value
is .19617 for positive=.5 and .00545 for positive=negative. The latter is an
additional, unadjusted sensitivity contrast; it does not replace a primary test.

The attitude-change summary retains equal group-issue-pair weights. Footnote 24
instead specifies averaging over issues within groups, then equally over groups.
Both are supplied, alongside an equal-poll comparison:

| Weighting | Mean absolute net change | Mean gross change |
|---|---:|---:|
| Equal group-issue pairs | .089414 | .202664 |
| Equal groups (footnote 24) | .097968 | .207801 |
| Equal polls | .097178 | .206419 |

The provenance of the published .092 net change remains unresolved. The earlier
audit should not have called .08941 its uniquely corrected replacement. All
three calculations support appreciable attitude change. No manuscript weighting
or interpretation has been silently replaced.

## Inference and scope

The article states that it uses Huber-White standard errors clustered by policy
index. The published code instead fits a per-poll random-intercept model by
issue and combines poll estimates with a fixed-effect meta-analysis.

The corrected primary analysis clusters by poll. This absorbs repeated groups,
repeated issues, and other shared poll-level conditions. A two-way group and
issue covariance estimate is retained as a sensitivity analysis in the
generated Table 2 file, but it assumes that cells within a poll are independent
when they share neither group nor issue. That assumption is too strong for the
primary analysis.

The 21 polls, and the 11 polls with income measures, were not randomly sampled.
The intervals therefore describe an exchangeable-poll sensitivity model. They
do not turn the selected polls into a probability sample or establish a causal
effect of deliberation.

## Reproduction and provenance

Run the complete correction from the repository root:

```sh
make restore
make ci
```

The authoritative outputs are:

- `tabs/02_table_2.csv`
- `tabs/03_table_3.csv`
- `tabs/05_attitude_change.csv`
- `tabs/05_attitude_change_weighting.csv`
- `tabs/09_paired_response_sensitivity.csv`
- `tabs/09_frequency_comparison.csv`
- `tabs/05_corr_hpd.csv`
- `tabs/07_parsing_domination.csv`
- `tabs/99_validation.csv`
- `figs/figure_manifest.csv`
- `provenance/claims.csv`, `values.csv`, `artifacts.csv`, and `checks.csv`

The repository has no editable manuscript source. The published PDF cannot be
rebuilt locally, so the journal article remains immutable. The claim ledger
identifies journal locations for numerical updates or author interpretation review.
The `paper-2022` tag preserves the original scripts, tables, figures, and data.
The working directories contain the current analysis and outputs.


## Reproducing the comparisons in the correction note

`make audit` runs `scripts/run_all.R` and the single audit entry point,
`scripts/checks.R`. `Rscript scripts/checks.R` runs the focused
comparisons against those saved outputs without regenerating the analysis.
Historical poll summaries are read from the `paper-2022` tag.

These comparisons hold other revised calculations fixed; they do not uniquely
decompose the difference between the published and revised results. They cover
unavailable subgroup means, reference ties and valid zeros, US Primaries
duplication, historical aggregation, and the combined-disadvantage predictor.
The script checks baseline scores, estimates, CR2 inference, and samples against
the release, and reconstructs the historical aggregation formula from archived
poll summaries. It prints the scenario results for inspection and stops on a
failed check.
