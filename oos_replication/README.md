# Out-of-sample deliberation study

This study asks whether the corrected paper's homogenization, polarization, and
domination patterns recur in previously unused Deliberative Polls, and whether
comparable changes occur in other deliberative formats. The original analysis is
fixed at commit `0e8f3867288acfe95285bff21a6bb8949d1ec9f5`.

[Current results](tabs/results.md) report each verified study, format and
outcome construct. [source_register.csv](source_register.csv) records the
included and deferred studies and the evidence behind exclusions. This is a
versioned public-data analysis, **not a completed systematic census**. New
eligible-looking sources are still emerging; the search stopping rule below
has not been met. Access gaps and unresolved instruments are not null findings.

The separate [replication and extension study](paper.pdf) uses generated tables,
figures and inline values. Its [LaTeX source](paper.tex) follows the original
paper's empirical organization: study inventory, magnitudes and occurrence,
subgroup movement, and net/gross attitude change. Deliberative Polls use
available-wave responses for the primary replication; other designs use paired
responses. The subgroup decomposition uses paired responses throughout so its
weighted identity is exact. Interpretation remains an author-review draft.

From the repository root:

```sh
git clone --branch v0.2.3 --depth 1 https://github.com/soodoku/dp-data.git ../dp-data
make restore
make oos-check
```

This reads the upstream files pinned in [files.csv](files.csv), checks their SHA-256 hashes,
and runs the R analysis, manuscript build, numerical checks and linting. Set
`DP_DATA_ROOT` if dp-data is elsewhere; a source archive works too. Original
URLs and access dates remain in the manifest and upstream source catalog. The
manuscript requires `latexmk` and a LaTeX installation. `make oos` regenerates
only the existing numerical results; `make oos-paper` also builds the parallel
artifacts and PDF. A changed source file stops the run; inspect and document the
new source version before updating its checksum. The shared R library is pinned
in the repository's `renv.lock`.

`scripts/run_all.R` is the entry point. Small `prepare_*.R` files contain the
explicit source mappings; `metrics.R` aggregates them using the original
analysis's movement definitions. `summarize.R` produces CSVs and a `knitr::kable`
report. Raw data and supporting documents live under dp-data’s `data/<study>/` paths.
Respondent/group-level intermediate RDS files stay in the ignored local `data/`
cache. Only metadata, code and compact aggregate outputs are versioned here. Reruns overwrite `tabs/`; Git preserves earlier versions.

`paper_tables.R` adds the subgroup components by calling the original shared
movement function, verifies every whole-group D against the existing OOS output,
and generates the manuscript tables and inline values. `paper_figures.R` renders
the corresponding grayscale histograms, boxplots and study means in `figs/`.
The original paper and its outputs remain separate.

The main comparison in `paper_overall.csv` combines original DPs, new DPs, and
other group discussions using paired policy ratings on a common scale. It shows
both equal-family/study and equal-group-item weighting; `paper_overall_families.csv`
and `paper_overall_omissions.csv` expose the contributing families and the result
of leaving each out. All conditions contribute to their study mean. Original polls
are separate families; A1R studies and consensus studies retain their known shared
families. Affective conversations remain separate from policy outcomes. With only
two new DP families, this comparison cannot establish a causal ranking of formats.

`paper_design_comparison.csv` and an appendix table retain the UK same-/mixed-party
and Diplomacy structured/unstructured contrasts as exploratory secondary results.
They do not yet exploit random assignment or the Diplomacy within-triad crossover.

| Original artifact | OOS counterpart |
|---|---|
| Table 1: poll inventory | `paper_inventory.csv` and manuscript Table 1 |
| Table 2: magnitude and occurrence | `paper_estimates.csv`; separate DP and extension panels |
| Table 3: parsing domination | `paper_components.csv`; paired whole-group and subgroup means/frequencies |
| Figure 3: H/P/D distributions | `figs/dp_distributions.pdf`; extension distributions by condition |
| Supplement: country/mode comparisons | Descriptive `figs/distributions_region.pdf` and `distributions_mode.pdf` |
| Text analyses: correlations and composition | `paper_correlations.csv` and `paper_composition.csv` |
| Text analysis: net/gross change | `paper_attitude_change.csv`, with both weighting conventions |

`paper_domination_sample.csv` reports contributing participants and group episodes
by study, construct and demographic dimension. `paper_frequency_inference.csv`
applies the existing family/df rule to positive frequencies. Composition predictions
are descriptive and limited to observed disadvantaged-share support. The item-level
appendix is `items.csv`, with instrument links; the paper explains source-specific
measurement limits. Figure inputs and cell counts are in `figs/figure_manifest.csv`.

## Reading the outputs

- `study_results.csv` and `event_results.csv`: estimates, valid group-item-episode
  counts, and fractions positive. Study results combine sites within a study;
  event results retain them. A1R2019 and A1R Climate remain separate studies.
- `minimum_five.csv`: the same event calculations requiring at least five
  observed respondents at each wave. Zero eligible pairs are shown explicitly.
- `pooled_results.csv`: estimates within format, construct and timing strata,
  under pair weighting and equal-family/equal-event weighting. `families`,
  `largest_family_share`, `df` and `inference` show the support for uncertainty
  estimates. Unavailable intervals are not evidence of no effect.
- `family_results.csv` and `leave_family_out.csv`: dependence-aware summaries
  and the consequences of omitting each study family.
- `sample_flow.csv` and `demographics.csv`: source-specific eligibility,
  classifications, missingness and median ties. `starting_rows` refers to the
  source or event sample at the stage indicated in each note; it is not a uniform
  count of all recruited people or all deposited records. Counts cannot be summed across
  repeated sites or overlapping studies to obtain independent participants.
- `whatsapp_identity_sensitivity.csv`: primary results alongside the source-supported
  exclusion of respondents flagged as potential duplicates or associates.
- `original_comparison.csv`: H, P and D from the corrected original's existing
  paired-response comparison. It compares indices with the new studies' individual
  items; this measurement difference limits substantive comparisons.

`items.csv` specifies raw wave columns, instrument endpoints, documented missing
codes, normalized midpoint, construct and topic-to-episode mapping. Its `event_id`
is the source mapping key; sources with multiple sites/arms receive separate event
IDs during preparation. `events.csv` describes those actual analysis events,
their shared dependence families and fieldwork/post timing. Partial dates remain
partial. `source_register.csv` separates archive publication dates from fieldwork
dates; unverified publication metadata remain missing.

The analysis cache `data/ratings.rds` has one row per participant, event, episode,
group and item: `t1`/`t2` are normalized private ratings; `gender`, `education`,
`income` and `combined` indicate the documented advantaged category, or missing.
`data/group_results.rds` retains all group-level scores and sample sizes for
inspection. `pairs` in tables counts nonmissing scores, not respondents. Positive
frequencies use the original numerical tolerance and retain genuine zeros in the
denominator. Missing reference directions are excluded metric by metric.

## Source decisions that matter

- **A1R2019:** the released four-category education variable has median 4 among
  included delegates. Strictly above-median education therefore identifies no
  advantaged subgroup; education D is unavailable. Income is absent. Five raw
  post cells coded `-8` follow the author's missing-value recode.
- **A1R Climate:** use the full documented 72-item instrument, with 65 policy
  items, three environmental-concern items and four climate-belief items in
  separate strata. ROOM crossed with schedule yields 105 observed groups,
  including a valid two-person group. The reported group count does not justify
  silently discarding it. The 139 returning A1R2019 attendees link the two studies
  into one dependence family.
- **Our Budget Our Economy:** 42 participants have conflicting pre/post table
  assignments and are excluded without inventing assignments. The 19 sites share
  a synchronous national event and count as one dependence family. Gender is
  frequently missing; H/P retain these respondents and D uses known categories.
- **Tanzania:** use the released household-to-group join and topic-specific round
  assignments. One assigned participant lacks the deliberation flag; assignment
  documentation supports retaining that record. Exclude two items with conflicting
  five-/seven-point documentation. Education coding is not sufficiently defined
  for a median split, and consumption is not silently substituted for income.
- **Hong Kong:** Study 1 has two groups of six. The casual-discussion group's
  initial mean is at the midpoint, so directional P is undefined; absolute P is
  still available. Study 2's video viewers are not discussion participants.
- **Celaya:** the 104 deliberators form seven sessions; Q&A respondents are outside
  this analysis. Baseline precedes the common information packet, so pre/post
  change spans both information and discussion. Multiple archive extracts reuse
  the same respondents.
- **UK echo chambers:** exclude three absent group keys, one key/date conflict
  and one contradictory control-size flag. Retain the valid two-person group;
  minimum-five results show the sensitivity. Baseline precedes discussion by
  1–82 days, although the post-survey is mostly same-day. Education categories do
  not define an unambiguous ordered scale; income is absent.

These are declared measurement and sample decisions, not proposed corrections
to the source papers. Any interpretation for the original manuscript remains
subject to discussion with the author.

Before calculating dyadic results, the following additional mappings were fixed:

- **US cross-party chats (February 2021):** include the 294 people in 147
  partnerships where both completed the chat, using the author's `full_cluster`
  flag. Of 516 conversation-assigned people, 222 are outside that documented
  completed-chat sample. Use nine repeated 0–100 feeling thermometers, with 50
  explicitly neutral. The post-wave follows the eight-minute chat; baseline is
  about an hour earlier. Other contact-preference and election-emotion scales
  are outside the selected thermometer family. Education codes need clarification;
  only gender D is used. Missing transcripts alone do not exclude participants.
- **India WhatsApp conversations:** the release contains 1,070 people completing
  the conversation period. Include the 712 people in 356 dyads assigned general
  political or intergroup prompts; exclude nonpolitical prompts. Keep topic and
  Hindu–Hindu/Hindu–Muslim composition separate. Use ten 1–5 affect ratings and
  eight repeated stereotype judgments in separate strata; stereotype P is left
  unavailable because a neutral midpoint is not documented. Use the first post-wave
  `s9`, retaining missing responses, and documented education/income classifications.
  Month codes span February–July, but the fieldwork year remains unverified and is
  recorded as missing. These dyads are outside the original poll inventory.

Dyadic H measures agreement between two participants about the same target.
Across all constructs, group-mean P differs from the distance between political
parties: a common shift can increase group-mean extremity while party means converge.
P applied to a feeling scale measures affective extremity relative to neutral;
it is not the usual in-party minus out-party measure of affective polarization.
These extensions remain separate from policy results and from larger groups.

WhatsApp also flags *potential duplicates or associates*, based on surveys,
messages or profiles. The author retains them in the main analysis and excludes
them in a [sensitivity analysis](https://dataverse.harvard.edu/api/access/datafile/13295178).
There are 52 flagged respondents across 49 included dyads. We retain them in the
primary results and record this sensitivity before calculating it: remove flagged
respondents, then apply the same paired/available rules and metric eligibility.
H consequently loses affected dyads; P can remain defined for an observed partner.
This is not a finding of confirmed duplication. Shared-family inference does not
eliminate possible changes in means or weights if records represent the same person.

The next source pass, also specified before calculating its outcomes, adds:

- **Refugee-policy consensus studies:** 116 pupils in 28 groups and 136 university
  students in 41 groups, with two private repeated policy ratings per study.
  The first study's unique `id` avoids a duplicated `ppnr` assigned to different
  people. Its released sample already excludes four groups containing non-native
  Dutch speakers. Seven-point fractional responses remain unchanged; the midpoint
  label is unverified, so this study supplies H/D but no P. The second study uses
  the documented five-point agreement scale and first post-discussion wave.
  Countries and designs are separate; the shared paper defines one study family.
  Fieldwork dates remain unavailable.
- **Diplomacy experiment, Study 3 (February 2020):** 105 people in 35 triads discuss
  two different topics under opposite structured/unstructured condition orders.
  Keep the original group IDs, topic IDs and rounds. The same 35 groups contribute
  both conditions; they are not 70 independent groups. Use private agreement before
  and after each round on the documented five-point scale with a neutral category.
  Topics about social media and homework are social judgments, reported separately
  from policy items. Topics were selected for initial disagreement; this selection
  limits comparisons with representative Deliberative Polls. Studies 1–2 lack
  verified released before-and-after substantive ratings and are excluded.

The Shizuoka addition is specified before calculating its H/P/D outcomes:
65 face-to-face participants in eight facilitated groups, using private T2 ratings
immediately before discussion and T3 ratings after two 90-minute discussions and
an expert panel. All eleven released items use the documented five-point agreement
scale, normalized as `(rating - 1) / 4`, with neutral midpoint 0.5. S1–10 concern
nuclear-restart decision procedures (policy); S11 concerns the accuracy of information
from restart proponents (belief), reported separately. These are not eleven measures
of support for restarting nuclear power. Source rows identify participants within
the wide file; no cross-wave identity matching is needed. Gender uses the labelled
male indicator; education uses the documented ordered categories and the event
median before item missingness. Income and combined advantage are unavailable.
The release contains the 65 face-to-face participants, not the 51 online participants
reported in the paper. Eight groups share one event/family; the exact 2019 date is
unverified. Existing paired/available, weighting and minimum-five rules apply.

## Discovery

`search_log.csv` records reproducible archive queries, web discovery queries and
bounded citation rounds. To refresh the archive queries explicitly:

```sh
Rscript oos_replication/scripts/search.R
```

The queries include harvested records and overlap; returned counts are not counts
of unique eligible studies. Raw search responses are cached in `data/`.
Refreshing appends distinct search records and preserves the manually recorded
web and citation searches; unrecorded web result totals remain missing.
The source register is the curated screening record, with specific missing
requirements for deferred candidates. The Stanford catalogue and the
[multidisciplinary review](https://doi.org/10.3389/fpos.2023.1127372) provide
discovery leads, not respondent datasets. National archive and author-site
screening is represented by the linked source records; this log does not claim a
complete search of every archive. No requests to authors have been sent.

The latest follow-up verifies public Shin-Kori 2017 respondent files, but no
discussion-group key. Denmark's breast-screening DP also releases repeated
attitudes in a companion archive; group linkage is its remaining obstacle.
Japan's national 2012 DP, Tamale 2015 and Iceland 2019 have public reports, but
no participant download was verified. The Caluwaerts-review citation round
screened eight priority references and added no analysis-ready public dataset.
Following three empirical references from the Shizuoka paper added no further
verified dataset: most Citizen Initiative Review baselines were recalled at the
end, its prospective 2014 panelist files remain unavailable, and the linked public
archive surveys voters. Ireland's 2011 assembly remains a public-data lead.
The Bloomfield Track jury used rankings and is linked to the existing Niemeyer
record as possible overlap. These targeted rounds do not complete the broader
search stopping rule.
These are documented access or measurement gaps, not evidence about H/P/D.

The September 12 expansion added 23 source records. A subsequent check of
Humphreys, Masters, and Sandbu's São Tomé study brings the register to 101,
without adding an eligible study. The priority follow-ups are:

- **AMR across six countries:** the current open release contains 1,280 treatment
  respondents and 1,139 controls at two waves. Actual room assignments are absent;
  2,419 is not the number of deliberators. Room and attendance linkage could make
  this a substantial addition.
- **Malawi 2017:** the flood-policy DP reports 480 baseline respondents, 468 post
  responses, 24 groups and 32 attitude items. Its paper explicitly offers microdata
  on author request. Related publications describe the same event.
- **A1R Democratic Reform, Meta forums, and further African/Mongolian DPs:**
  official reports establish additional events, but participant files with rooms
  have not been verified. DeliberationBench's public code references unreleased
  local input files and does not independently supply those data.
- **National archives:** Danish DP deposits and Korean KBS pre/post survey records
  are concrete archive leads. Access and group linkage still need resolution.
  Finland FSD2975 was successfully downloaded without registration, correcting
  our earlier access classification; its 101-row release lacks verified matched
  policy waves and actual group IDs, so it remains outside the analysis.
- **Comparative designs:** AHRQ's 2012 trial includes four deliberative methods,
  including online DP, and a reading-only control: 961 discussants in 76 groups
  plus 377 controls. Its conditional assignment and documented late nonrandom
  control assignments require care; no public microdata release was verified.
- **São Tomé National Forum (2004):** the authors' public
  [replication archive](https://macartan.github.io/code/wp2007/HMS_REP.zip)
  contains 148 group records and a survey file with 76 rows containing some
  responses at both waves (23–74 paired responses per item). The survey file
  lacks participant IDs, group IDs, and demographics. These files support study
  of facilitator influence on reported collective decisions; the current
  within-group H/P/D comparison requires additional survey-to-group linkage.

The added records include event leads and secondary analyses, not 23 independent
new studies. No requests have been sent. The search remains open.

Independent review compared the included source events with the original data's
21 poll identifiers, names and index mappings and found no event overlap.
Universal respondent identifiers are unavailable, so person-level non-overlap
with the original archive cannot be proved mechanically. Known overlap within
the new corpus is retained in the dependence-family definitions.

## Protocol recorded before new outcome calculations

Recorded September 11, 2026. Public papers and source documentation have already
been read, and variable availability and sample sizes inspected. This is a
retrospective analysis plan, not a blinded preregistration. Independent design
review identified participant overlap, changing wave membership, missing group
identifiers, and sparse independent events as principal risks.

Search public material available through September 11, 2026: Stanford's project
catalogue, Dataverse, OSF, ICPSR, national archives, research-team websites, and
deliberation registries. Search variants of deliberation, deliberative poll,
mini-public, citizens' assembly/jury, discussion experiment, and polarization;
follow references and citing studies from reviews and eligible studies. Record
searches and dispositions, including inaccessible sources. Discovery remains open
until these searches and two successive citation rounds yield no new eligible
studies. No author requests will be sent without authorization.

Eligibility is specific to group, item, episode, and metric. Require actual
interaction groups, structured discussion of reasons/evidence, private individual
ratings before and after the episode, and documented comparable instruments.
Do not substitute treatment arms, venues, or collective verdicts for discussion
groups or private ratings. Ordinary non-deliberating panels are outside scope.
Exclude the original 21 polls and record repeated publications and cohorts.

The direct replication uses available responses at each wave. The extension's
primary sample uses the same respondents at both waves, item by item; both rules
are reported for every included event. Use the last pre-deliberation and first
post-deliberation measurement; report intervals and separate later follow-ups.
No outcome, group-identity, or demographic imputation. Normalize by documented
instrument endpoints, never observed sample extrema. Keep policy attitudes,
affective ratings, and other judgments in separate outcome strata. Rankings and
nominal choices do not acquire cardinal scores merely to enter this analysis.

H is sample SD before minus sample SD after. Directional P is movement away from
the initial group mean's direction relative to the scale midpoint; also report
change in absolute distance from the midpoint. Primary P requires a defensible
midpoint. D is movement of the whole-group mean toward the initial advantaged
subgroup mean. Reuse the corrected paper's movement function: reference ties are
undefined, genuine zero movement remains zero. Require two observed respondents
per wave for H and both demographic categories for D. Whole-group D requires
the initial advantaged mean and the whole-group means at both waves; an
unavailable post-discussion subgroup mean alone does not invalidate it. Report a minimum-five
respondent sensitivity. Recompute D's means and reference on the eligible sample.

Gender, education, income, and combined advantage follow the paper where source
definitions permit: male, above-median education, above-median income, and the
intersection of those three. Calculate socioeconomic thresholds among participating
delegates within each event before outcome-specific filtering; report ties and missing categories.
Context and measurement must support each classification. Proxy socioeconomic
measures and additional dimensions remain separate exploratory outcomes.

Report events first, separating Deliberative Polls from other formats. Pool only
comparable outcome strata, weighting each valid group-item-episode equally.
Sensitivity: equal independent-family weight, then equal event weight within
family; leave one family out. Link known overlapping participants and rounds in
one event family. Use CR2/Satterthwaite at that level, reporting effective degrees
of freedom and largest-family share. With fewer than two families, non-estimable
covariance, or effective df below four, report estimates without inferential
claims. Display intervals rather than significance stars; no confirmatory claims
are planned. Any subsequent confirmatory tests require a stated family and Holm
adjustment.

Fieldwork date, baseline/post timing, publication date, and source-version access
date are separate fields. Older unused studies are out of sample but not later
temporal replications. Format and date comparisons describe the observed corpus;
within-group change does not by itself identify deliberation's causal effect,
subgroup influence, or a mechanism. Discuss material interpretation changes with
the author before revising manuscript claims.

## Validation and delivery

One R entry point obtains version-checked sources, prepares eligible data,
calculates outcomes, and writes tables. Source-specific transformations remain
small, explicit R scripts; shared metric definitions stay in the original helper
file. The source register and item dictionary document joins, codes, exclusions,
and unresolved definitions. Raw files are stored once upstream and verified against downstream pins.

Validate source sample counts, unique keys, documented bounds and missing codes,
join cardinality, genuine group identity, overlap, row-order invariance, and
hand-calculated H/P/D examples. Run the original checks and independent review.
Deliver a PR with source dispositions, sample flows, event results and comparison
to the corrected paper. Public-data access gaps remain explicit, not silently
treated as evidence of absent effects or as completed replication.
