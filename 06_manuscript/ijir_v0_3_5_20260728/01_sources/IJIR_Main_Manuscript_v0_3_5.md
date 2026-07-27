# Bidirectional Mendelian randomization of gut microbial traits and erectile dysfunction with cross-cohort same-SNP evaluation and multiplicity control

Short title: Gut microbial traits and erectile dysfunction

## Abstract

Prior Mendelian randomization (MR) studies reported gut microbial traits associated with erectile dysfunction (ED), often using relaxed instruments and nominal tests. We reassessed this relationship using 1 572 Swedish shotgun-metagenomic traits, FinnGen R12 ED, a 2025 multi-ancestry ED GWAS, and exact-label HUNT data. Primary instruments required P<5×10⁻⁸ and F>10; eligibility and multiplicity criteria were defined before screening. Of 230 forward traits, 218 were estimable and seven nominal, but none passed false-discovery-rate (FDR) control; none of 1 572 reverse tests passed FDR. HUNT covered 97 labels: 76/97 rows and 69/90 unique rsIDs were direction-concordant, but both focal associations were weak without genome-wide-significant HUNT instruments. European and cross-ancestry sensitivities each yielded the same eight trait-level associations surviving FDR correction, driven by three high-LD SNPs in one chr2q21 lactase-persistence region. The non-overlapping African-ancestry sensitivity yielded none, with only 2/8 rows estimable. Targeted post hoc annotation raised substantial horizontal-pleiotropy concerns. The median minimum detectable OR for 80% power was 2.89 per standardized exposure unit at the forward Bonferroni threshold (α=0.05/230). No association met the criteria defined before screening for robust causal interpretation; small effects cannot be excluded.

Keywords: erectile dysfunction; gut microbiome; Mendelian randomization; FinnGen; HUNT; multiple testing

## Introduction

Erectile dysfunction (ED) is a multifactorial disorder with vascular, metabolic, neurological, hormonal, and psychological determinants.[1] Gut dysbiosis could plausibly influence erectile physiology through insulin resistance, systemic inflammation, microbial metabolites, and endothelial dysfunction, but observational associations remain vulnerable to confounding, medication use, diet, and reverse causation.[2,3] Recent IJIR studies illustrate the clinical interest in microbiota, inflammation, and metabolic markers in ED.[2,29]

Four published two-sample Mendelian randomization (MR) studies have reported nominal gut microbial taxa associated with ED.[6–9] Most drew microbial instruments from MiBioGen[4] at P<1×10⁻⁵ and used the earlier European ED genome-wide association study (GWAS).[5] Differences in selected taxa, sparse instruments, incomplete multiplicity control, and limited independent evaluation make reproducibility uncertain; these limitations do not imply that the earlier findings are necessarily false.

Swedish and HUNT shotgun-metagenomic GWASs, FinnGen R12, and a larger 2025 ED GWAS permit a stricter reassessment.[11–14] We tested both directions using genome-wide-significant instruments, complete denominators, cross-cohort same-SNP exposure evaluation, multiplicity sensitivities, and evidence classification for overlap, ancestry transfer, locus redundancy, pleiotropy, and effect scale.

## Materials and methods

### Study design and data sources

This summary-data study followed STROBE-MR and general summary-data MR guidance.[10,24] Eligibility and multiplicity rules were defined before association screening; dated mechanism-specific records are described separately below. Swedish GWASs comprised 1 572 microbial presence, rank-based inverse-normal (RIN) abundance, higher-taxonomic, functional, and diversity traits in 16 017 European-ancestry adults.[11] HUNT provided exact-label normalized relative-abundance GWASs in up to 12 652 Norwegian participants.[12] No fuzzy taxonomic matching was used.

FinnGen R12 ED (2 886 cases; 215 272 controls) was the primary forward outcome: a male-specific phenotype requiring at least three phosphodiesterase-5-inhibitor purchases after exclusion of pulmonary-hypertension indications.[13] Its coherent treated-ED phenotype supplied interpretable log-odds estimates. The 2025 meta-GWAS combined diagnostic-code, prescription, and self-report definitions and supplied European (136 867 cases; 776 327 controls), African-ancestry (51 599 cases; 73 716 controls), and cross-ancestry (188 466 cases; 850 043 controls) sensitivities and the reverse exposure.[14] European and cross-ancestry results included FinnGen. The African stratum comprised All of Us and the Million Veteran Program without FinnGen; it was ancestry-transfer evidence because the instruments were European and coverage, LD, allele frequency, phenotype, and transportability differed.

METAL used cumulative effective-sample-size weights, with effective sample size 4/(1/n_cases+1/n_controls).[14] Per SNP, we reconstructed β*=Z/√W and SE*=1/√W; β*/SE*=Z and P was preserved apart from Z rounding. This screening scale is not an ED log-odds or clinically interpretable OR scale (Table 1).

### Instruments, harmonization, and effect scales

Primary microbial instruments required P<5×10⁻⁸, F>10, and European LD clumping at r²<0.001 within 10 000 kb using 503 1000 Genomes Phase 3 European participants.[15,16] Per-trait clumping allowed different traits to retain correlated variants; cross-trait compression occurred only post hoc. GRCh37 microbial and GRCh38 ED data were matched by exact rsID and compatible A/C/G/T alleles, without proxies or coordinate matching. Palindromes required EAF in both datasets, minor-allele frequency ≤0.42, and exactly one orientation within EAF tolerance 0.10; all others were excluded. Multiple compatible matches were excluded as multiallelic ambiguity. Presence effects are ED ORs per unit of genetically predicted microbial-presence log odds; RIN effects are per source-standardized unit.

For reverse MR, 479 European ED variants met P<5×10⁻⁸ and F>10; 437 were present and allele-matched in the 1000 Genomes Phase 3 EUR GRCh37 reference, and PLINK clumping at r²<0.001 over 10 000 kb retained 24.[15,16] Exact-rsID lookup used the same harmonization; missing variants were recorded and proxies prohibited. Reverse effects retain the Z/√W scale for statistical screening only.

The source paper used study-wide thresholds of 1.7×10⁻⁸ for diversity, 5.4×10⁻¹¹ for species and higher taxa, and 4.3×10⁻¹⁰ for functions.[11] We repeated forward selection, clumping, harmonization, and MR at those trait-class thresholds as a sensitivity analysis.

### MR estimation, multiplicity, and diagnostic analyses

Single-variant effects used Wald ratios; multi-variant effects used multiplicative random-effects inverse-variance weighting. Cochran Q, weighted median, MR-Egger, and MR-RAPS were reported only when requirements were met; warnings and convergence failures were retained.[17–20] MR-PRESSO and leave-one-out were candidate-triggered, but no association met the corrected trigger.[22] A revision-stage Steiger feasibility audit covered all forward traits. Binary-outcome population prevalence was undefined and presence traits required additional liability assumptions, so outcome R² and valid Steiger P values were not calculated; non-estimability was not directional support.[21]

BH families contained all 230 eligible forward and 1 572 reverse tests, retaining non-estimable tests at P=1.[23] The cross-direction Bonferroni threshold was 0.05/1 802. Sensitivities used 218 estimable tests and 225 deterministic clusters of identical coefficients and nested taxonomy; representatives followed frozen source-ID order, not outcome P. Peptococcaceae, Peptococcales, and Peptococcia formed one cluster. Each 2025 outcome was a separate 230-trait family with non-estimable P=1; estimable-only BH was secondary.

### Cross-cohort same-SNP exposure evaluation

For each exact-label HUNT match, the Swedish lead SNP was queried at the same GRCh37 position and allele-aligned; signed Z and direction, not raw coefficients, were compared across different phenotype scales. Exact-binomial concordance intervals did not model microbial-trait correlation. A sensitivity retained each unique Swedish lead rsID once after confirming no within-rsID direction conflict; the 90 rsIDs were not necessarily independent LD loci. Legacy HUNT-specific P<1×10⁻⁵ instruments paired with FinnGen remained exploratory, not independent replication.

### Targeted post hoc explanatory audit

After alternative-outcome FDR signals appeared, a targeted post hoc audit was restricted to their frozen rows and three lead SNPs. Rows were compressed to unique variants and European-LD loci at 1000 Genomes Phase 3 pairwise r²≥0.8. No outcome-P-selected representative or locus P/q was created. Ensembl, exact-rsID GWAS Catalog, and exact-rsID OpenGWAS queries (accessed 23 July 2026) annotated genes and phenotypes.[32–34] OpenGWAS used P<1×10⁻⁵ without proxies; counts were descriptive. “Not identified under the specified query and threshold” was not evidence of absence. This audit and annotation of seven primary nominal rows were outside the multiplicity analysis.

Formal regional colocalization was not performed: the ED release lacked EAF and supplied a non-clinical METAL scale rather than a validated binary-outcome likelihood. Z-only analysis with external LD would add unvalidated assumptions. Exact-rsID annotation could therefore raise pleiotropy concerns but not establish a shared causal variant or microbial mediation.

### Power and minimum detectable effects

For RIN traits, R²≈Σ2EAF(1−EAF)β². Presence traits used a liability approximation from log-odds beta, EAF, sample size, and reported prevalence, with ±0.10 scenarios.[28] For 2 886 cases and 215 272 controls, mRnd was root-solved for 80%-power ORs at α=0.05, 0.05/230, and 0.05/1 802.[27] MDEs are per standardized exposure unit—an approximate liability-scale SD for presence—and are detectability summaries, not the primary presence-trait log-odds-unit OR. Inputs and checks are supplied per trait.

### Prespecified bounded mechanistic screening

The bounded protocol was frozen on 21 July 2026 before mediator results were inspected. Five HUNT modules were chosen by biological rationale plus genome-wide-significant, F>10 eligibility, without ED P values: lipopolysaccharide (M00080), phosphatidylcholine (M00091), GABA (M00136), nitrate-reduction (M00530), and catechol-meta-cleavage (M00569) pathways. They were screened with 40 cytokines and nine endothelial proteins in seven complete families (5, 40, 9, 200, 45, 200, and 45 tests).[25,26] Non-estimable rows had P=1; delta-method products were not called causal mediation. Data independence meant no identified shared cohort; unresolved or known overlap remained screening-only. Mediation-compatible evidence additionally required component and indirect FDR, direction, and colocalization. Supplementary Data provide selections, overlap labels, freeze receipt, and results.

### Software and reproducibility

Analyses used R and pinned PLINK in a versioned environment. SHA-256 records linked inputs and outputs; original GWAS files were unmodified. OpenAI Codex assisted code review, language editing, and consistency checks after analytical criteria had been defined. It did not select traits or determine statistical significance; the authors verified all outputs and remain accountable for the work.

## Results

### Primary bidirectional analyses

Of 230 forward-eligible traits, 218 were estimable: 194 (89.0%) used one SNP, 18 two, one three, and five four (Figure 3c). Seven single-SNP Wald estimates were nominal, but none passed FDR (minimum P=0.00720; q=0.9416; Table 2; Figures 2–3). Three Peptococcaceae rows were one identical nested cluster. Weighted median and MR-Egger were estimable for six traits each; MR-RAPS for 23, with one fit that failed to converge and was retained as a recorded failure. Cochran Q was available for 24 multi-SNP traits and the MR-Egger intercept for six. MR-PRESSO and leave-one-out were not triggered and were impossible for the seven single-SNP nominal rows. Steiger was not estimable under the required binary-outcome and presence-scale assumptions; no directional support was inferred.

The reverse analysis used 24 independent ED instruments and estimated all 1 572 microbial outcomes. Seventy-seven had nominal P<0.05, but none passed reverse-family FDR (minimum P=0.00186; minimum q=0.9673; Figure 2b). Across the 6 288 robust-method rows, 6 184 were estimated and 104 MR-RAPS rows retained explicit failures.

### Multiplicity and source-threshold sensitivities

No forward association passed estimable-only BH (n=218; minimum q=0.8925) or unique-signal-cluster BH (n=225; minimum q=0.9605). At source-study-wide thresholds, 27 traits remained eligible, 23 were estimable, four were non-estimable, and none had nominal P<0.05 (minimum P=0.1533; minimum q=1; Supplementary Figure S4).

### 2025 ED outcome sensitivity and locus structure

The separate 230-trait European, African-ancestry, and cross-ancestry families contained 158, 108, and 165 estimable rows; 72, 122, and 65 non-estimable rows were retained at P=1. European and cross-ancestry analyses each contained the same eight trait-level associations surviving full-family FDR correction (minimum P=6.39×10⁻⁵; q=0.00594); African ancestry contained none. Estimable-only BH did not change the sets. Five rows used rs4988235, two rs6754311, and one rs7570971. Per-trait clumping did not remove these cross-trait variants despite European LD r²=0.859–0.972. Post hoc compression yielded three single-SNP estimands within one chr2q21 locus; *Phocea massiliensis* and *Phocea* were nested and identical. No locus P or q was calculated.

Seven of eight rows had the same direction in FinnGen and European estimates, but none was nominal in FinnGen (P=0.613–0.979; q=1). Only the two rs6754311 rows were estimable in African ancestry; both matched the European direction but had P=0.731 and q=1. Six rows lacked African-ancestry SNP coverage, so non-estimability was not evidence of absence. Targeted exact-rsID annotation placed rs4988235 in an MCM6 regulatory region controlling LCT and lactase persistence.[31] Broad dietary, metabolic, haematological, and microbiome associations across the region raised substantial horizontal-pleiotropy concerns and did not distinguish microbial mediation from alternative pathways. Formal regional colocalization was not feasible under the available ED fields and scale. European and cross-ancestry results included FinnGen and were outcome-dependent sensitivity evidence, not independent confirmation (Supplementary Tables S11 and S13–S15; Figure S6).

### Cross-cohort same-SNP exposure evaluation

All 97 exact-label Swedish lead-SNP rows were found and allele-compatible in HUNT; 76 directions were concordant (78.4%; descriptive 95% CI 68.8%–86.1%). They represented 90 unique rsIDs, not necessarily independent loci; one deterministic row per rsID gave 69/90 concordant (76.7%; 95% CI 66.6%–84.9%). Neither interval models microbial-trait correlation. *Fimisoma avicola* and UBA644 sp900547165 had no HUNT instrument at P<5×10⁻⁸, and their same-SNP exposure associations were weak (P=0.965, F=0.002; P=0.671, F=0.180). Exploratory HUNT-selected analyses used 23 and 20 SNPs at P<1×10⁻⁵ and were non-significant (P=0.427 and P=0.175; Supplementary Figure S3 and Table S12).

The seven primary nominal rows mapped to five unique SNPs. Under the specified exact-rsID GWAS Catalog query and threshold, no association was identified for four SNPs; this was not evidence of absence. rs62103891 was associated with programmed cell death protein 5 measurement (P=7×10⁻⁶⁴), creating a possible but unresolved pleiotropy concern. None was within 1 Mb of FUT2, LCT, or ABO (Supplementary Table S8).

### Detectability and mechanistic screening

Across 218 traits, approximate R² had a median of 0.00203 (IQR 0.00168–0.00274; range 0.00137–0.00760). On the standardized MDE scale, median 80%-power ORs were 2.17 at α=0.05 (IQR 2.01–2.29; range 1.61–2.43), 2.89 at the forward Bonferroni threshold α=0.05/230 (IQR 2.63–3.08; range 1.98–3.29), and 3.09 at α=0.05/1 802 (IQR 2.81–3.29; range 2.09–3.53). Fifty-four traits could detect OR≥2 at nominal α, compared with one at α=0.05/230 and none globally (Figure 3c; Supplementary Table S5).

The bounded mechanistic workbook contained all 544 planned rows, including 185 non-estimable rows. No family produced an FDR association (minimum q by family 0.395–1.000; Supplementary Figure S5). CCL11-to-ED was nominal (P=0.0358; q=1) but its cis lead showed source heterogeneity (I²=86.8%; P=0.00587) and was excluded in the predefined sensitivity. No component pair jointly passed FDR, so colocalization was not triggered and no pathway received a mediation-compatible interpretation.

## Discussion

No primary FinnGen forward or reverse association passed FDR. The larger European and cross-ancestry outcomes instead yielded the same eight trait-level associations surviving FDR correction, concentrated in three correlated single-variant estimands within one lactase-persistence locus. No association met the criteria defined before screening for robust causal interpretation; the targeted post hoc audit further limited specificity. This discordance does not prove absence of a gut microbial effect.

Four earlier microbiome–ED MR studies reported nominal taxa,[6–9] usually using MiBioGen[4], P<1×10⁻⁵ instruments, and the earlier ED GWAS.[5] Our study differs in platform, taxonomy, instrument threshold, denominator, and overlap handling. The IJIR microbiome MR report selected instruments at P<1×10⁻⁵ and highlighted six nominal taxa.[8] These differences do not directly refute historical taxa, but show why isolated P<0.05 results need independent evaluation.

The MDE analysis clarifies what the negative result can and cannot exclude. At the forward Bonferroni threshold (α=0.05/230), the median detectable OR was 2.89 per standardized exposure unit, and only one trait had 80% power for an OR of 2 on that scale. The study therefore has little ability to exclude small or moderate effects. For presence traits, the MDE uses an approximate prevalence-dependent liability-scale standard deviation and cannot be compared directly with the primary MR OR per one-unit genetically predicted log odds.

HUNT added an independent exposure cohort, not formal validation or MR replication. Concordance was substantial, but correlated traits make the intervals descriptive. The two focal traits had weak same-SNP HUNT associations and no genome-wide-significant HUNT instruments; exploratory HUNT-selected P<1×10⁻⁵ analyses reused FinnGen. Swedish presence and HUNT abundance effects cannot be compared numerically.

Instrument architecture remains the principal limitation. Eighty-nine percent of estimable forward traits and all seven nominal rows used one SNP, precluding informative MR-Egger, heterogeneity, MR-PRESSO, or leave-one-out analyses at those loci. “Not identified” in an exact-rsID database query is not evidence that pleiotropy is absent. Moreover, microbial SNPs were selected and scaled in the same Swedish discovery GWAS. Winner’s curse may therefore have inflated SNP–exposure estimates, biased single-variant Wald estimates toward the null, and made discovery-based F, R², and MDE summaries optimistic. The weak HUNT exposure associations for both focal SNPs are compatible with limited cross-cohort stability, but do not prove invalid instruments.

FinnGen's male-specific repeated-purchase phenotype captures recognized and pharmacologically treated ED with interpretable log-odds estimates. Untreated or unrecorded ED may have been classified among controls. Pulmonary-hypertension indications were excluded, but exclusion of every non-ED G04BE use was undocumented; tadalafil for lower urinary tract symptoms could add misclassification. The post hoc audit showed that eight associations were not eight independent findings: per-trait clumping retained three high-LD variants in one LCT/MCM6 region. Broad phenotype associations were compatible with pleiotropy but neither proved horizontal pleiotropy nor assigned microbial mediation; exact-rsID annotation was not colocalization. Overlap, single-SNP architecture, nested traits, the non-clinical Z/√W scale, and incomplete African coverage prevent independent confirmation. African results neither validate nor refute the European signal because only two rows were estimable and transportability is uncertain.

Inflammation, insulin resistance, metabolites, and endothelial dysfunction remain biologically plausible in ED and are active topics in IJIR.[29,30] However, the bounded two-step screening found no pathway meeting its component criteria, and CCL11 failed source-heterogeneity sensitivity. We therefore do not describe this extension as formal causal mediation and did not expand it into unplanned metabolite, immune-cell, or pathway panels.

Clinically, no microbial trait should be prioritized as an ED treatment target from these MR results alone. Future studies need larger ancestry-diverse shotgun GWASs, standardized taxonomic crosswalks, independent non-overlapping ED outcomes, stronger instruments for microbial functions and metabolites, and colocalized multi-omic evidence. Until then, strict multiplicity control and explicit detectability limits are preferable to interpreting nominal taxa as established therapeutic targets.

## Data availability

The primary MR outputs were frozen before the explanatory audit. Submission-associated code, frozen outputs, derived locus and pleiotropy audits, provenance records, and final supplementary materials are archived in GitHub release v0.3.5 (https://github.com/DuXC/gut-microbiome-ed-mr/releases/tag/v0.3.5) and Zenodo (version DOI https://doi.org/10.5281/zenodo.21630442; concept DOI https://doi.org/10.5281/zenodo.21456670). Restricted third-party GWAS payloads are not redistributed.

## Acknowledgements

We thank the participants and investigators of FinnGen, the Swedish microbiome cohorts, HUNT, All of Us, UK Biobank, the Million Veteran Program, the Estonian Biobank, the Partners HealthCare Biobank, the cytokine meta-GWAS, and SCALLOP.

## Author contributions

X.D.: Conceptualization, methodology, software, formal analysis, data curation, visualization, project administration, and writing—original draft. S.T.: Investigation, data curation, validation, and writing—review and editing. K.X.: Investigation, data curation, validation, and writing—review and editing. Y.Z.: Methodology, formal-analysis verification, validation, and writing—review and editing. Y.S.: Investigation, validation, and writing—review and editing. H.G.: Investigation, data curation, validation, and writing—review and editing. M.C.: Resources, clinical interpretation, supervision, and writing—review and editing. C.L.: Conceptualization, supervision, funding acquisition, and writing—review and editing. C.S.: Conceptualization, methodology, supervision, validation, project administration, funding acquisition, and writing—review and editing. All authors reviewed and approved the manuscript and accept accountability for the work.

## Funding

This work was supported by the Jiangsu Provincial Research Project on Traditional Chinese Medicine and Integrated Chinese-Western Medicine (ZXFZ2026021; Chao Sun) and the China Postdoctoral Science Foundation (2024M750457; Chunhui Liu). The funders had no role in study design, analysis, interpretation, manuscript preparation, or the decision to submit.

## Ethical approval

No new ethical approval or participant consent was required because only publicly available, deidentified GWAS summary statistics were analyzed. The original studies obtained appropriate approvals and consent.

## Competing interests

The authors declare no competing interests.

## References

1. Yafi FA, Jenkins L, Albersen M, Corona G, Isidori AM, Goldfarb S, et al. Erectile dysfunction. Nat Rev Dis Primers. 2016;2:16003. doi:10.1038/nrdp.2016.3.
2. Russo GI, Bongiorno D, Bonomo C, Musso N, Stefani S, Sokolakis I, et al. The relationship between the gut microbiota, benign prostatic hyperplasia, and erectile dysfunction. Int J Impot Res. 2023;35:350–355. doi:10.1038/s41443-022-00569-1.
3. Fan Y, Pedersen O. Gut microbiota in human metabolic health and disease. Nat Rev Microbiol. 2021;19:55–71. doi:10.1038/s41579-020-0433-9.
4. Kurilshikov A, Medina-Gomez C, Bacigalupe R, Radjabzadeh D, Wang J, Demirkan A, et al. Large-scale association analyses identify host factors influencing human gut microbiome composition. Nat Genet. 2021;53:156–165. doi:10.1038/s41588-020-00763-1.
5. Bovijn J, Jackson L, Censin J, Chen CY, Laisk T, Laber S, et al. GWAS identifies risk locus for erectile dysfunction and implicates hypothalamic neurobiology and diabetes in etiology. Am J Hum Genet. 2019;104:157–163. doi:10.1016/j.ajhg.2018.11.004.
6. Zhang Y, Chen Y, Mei Y, Xu R, Zhang H, Feng X. Causal effects of gut microbiota on erectile dysfunction: a two-sample Mendelian randomization study. Front Microbiol. 2023;14:1257114. doi:10.3389/fmicb.2023.1257114.
7. Zhang F, Xiong Y, Zhang Y, Wu K, Zhang B. Genetically proxied intestinal microbiota and risk of erectile dysfunction. Andrology. 2024;12:793–800. doi:10.1111/andr.13534.
8. Xu R, Liu S, Li LY, Zhang Y, Fang BQ, Luo GC, et al. Causal effects of gut microbiota on the risk of erectile dysfunction: a Mendelian randomization study. Int J Impot Res. 2024;36:858–863. doi:10.1038/s41443-024-00824-7.
9. Zhu T, Liu X, Yang P, Ma Y, Gao P, Gao J, et al. The association between the gut microbiota and erectile dysfunction. World J Mens Health. 2024;42:772–786. doi:10.5534/wjmh.230181.
10. Skrivankova VW, Richmond RC, Woolf BAR, Yarmolinsky J, Davies NM, Swanson SA, et al. Strengthening the reporting of observational studies in epidemiology using Mendelian randomization. JAMA. 2021;326:1614–1621. doi:10.1001/jama.2021.18236.
11. Dekkers KF, Pertiwi K, Baldanzi G, Lundmark P, Hammar U, Moksnes MR, et al. Genome-wide association analyses highlight the role of the intestinal molecular environment in human gut microbiota variation. Nat Genet. 2026;58:540–549. doi:10.1038/s41588-026-02512-2.
12. Moksnes MR, Coward E, Nethander M, Dekkers K, Grahnemo L, Törnqvist AE, et al. The HUNT study identifies host genetic factors reproducibly associated with human gut microbiota composition. Nat Genet. 2026;58:530–539. doi:10.1038/s41588-026-02502-4.
13. Kurki MI, Karjalainen J, Palta P, Sipilä TP, Kristiansson K, Donner KM, et al. FinnGen provides genetic insights from a well-phenotyped isolated population. Nature. 2023;613:508–518. doi:10.1038/s41586-022-05473-8.
14. Bright U, Chen Y, Deak JD, Zhou H, Levey DF, Gelernter J. Multi-ancestry investigation of the genomics of erectile dysfunction. Nat Commun. 2025;16:11602. doi:10.1038/s41467-025-66723-7.
15. 1000 Genomes Project Consortium. A global reference for human genetic variation. Nature. 2015;526:68–74. doi:10.1038/nature15393.
16. Chang CC, Chow CC, Tellier LC, Vattikuti S, Purcell SM, Lee JJ. Second-generation PLINK: rising to the challenge of larger and richer datasets. Gigascience. 2015;4:7. doi:10.1186/s13742-015-0047-8.
17. Burgess S, Butterworth A, Thompson SG. Mendelian randomization analysis with multiple genetic variants using summarized data. Genet Epidemiol. 2013;37:658–665. doi:10.1002/gepi.21758.
18. Bowden J, Davey Smith G, Haycock PC, Burgess S. Consistent estimation in Mendelian randomization with some invalid instruments using a weighted median estimator. Genet Epidemiol. 2016;40:304–314. doi:10.1002/gepi.21965.
19. Bowden J, Davey Smith G, Burgess S. Mendelian randomization with invalid instruments: effect estimation and bias detection through Egger regression. Int J Epidemiol. 2015;44:512–525. doi:10.1093/ije/dyv080.
20. Zhao Q, Wang J, Hemani G, Bowden J, Small DS. Statistical inference in two-sample summary-data Mendelian randomization using robust adjusted profile score. Ann Stat. 2020;48:1742–1769. doi:10.1214/19-AOS1866.
21. Hemani G, Tilling K, Davey Smith G. Orienting the causal relationship between imprecisely measured traits using GWAS summary data. PLoS Genet. 2017;13:e1007081. doi:10.1371/journal.pgen.1007081.
22. Verbanck M, Chen CY, Neale B, Do R. Detection of widespread horizontal pleiotropy in causal relationships inferred by Mendelian randomization between complex traits and diseases. Nat Genet. 2018;50:693–698. doi:10.1038/s41588-018-0099-7.
23. Benjamini Y, Hochberg Y. Controlling the false discovery rate: a practical and powerful approach to multiple testing. J R Stat Soc Series B Stat Methodol. 1995;57:289–300. doi:10.1111/j.2517-6161.1995.tb02031.x.
24. Burgess S, Davey Smith G, Davies NM, Dudbridge F, Gill D, Glymour MM, et al. Guidelines for performing Mendelian randomization investigations. Wellcome Open Res. 2020;4:186. doi:10.12688/wellcomeopenres.15555.2.
25. Konieczny MJ, Omarov M, Zhang L, Malik R, Richardson TG, Baumeister SE, et al. The genomic architecture of circulating cytokine levels points to drug targets for immune-related diseases. Commun Biol. 2025;8:34. doi:10.1038/s42003-025-07453-w.
26. Folkersen L, Gustafsson S, Wang Q, Hansen DH, Hedman ÅK, Schork A, et al. Genomic and drug target evaluation of 90 cardiovascular proteins in 30 931 individuals. Nat Metab. 2020;2:1135–1148. doi:10.1038/s42255-020-00287-2.
27. Burgess S. Sample size and power calculations in Mendelian randomization with a single instrumental variable and a binary outcome. Int J Epidemiol. 2014;43:922–929. doi:10.1093/ije/dyu005.
28. Lee SH, Goddard ME, Wray NR, Visscher PM. A better coefficient of determination for genetic profile analysis. Genet Epidemiol. 2012;36:214–224. doi:10.1002/gepi.21614.
29. Mei Y, Li Y, Zhang B, Xu R, Feng X. Association between the C-reactive protein-triglyceride glucose index and erectile dysfunction in US males: results from NHANES 2001–2004. Int J Impot Res. 2025;37:612–622. doi:10.1038/s41443-024-00945-z.
30. Xu R, Liu S, Li LY, Bu Y, Bai PM, Luo GC, et al. Exploring the causal association between serum metabolites and erectile dysfunction: a bidirectional Mendelian randomisation study. Int J Impot Res. 2025;37:601–611. doi:10.1038/s41443-024-00926-2.
31. Enattah NS, Sahi T, Savilahti E, Terwilliger JD, Peltonen L, Järvelä I. Identification of a variant associated with adult-type hypolactasia. Nat Genet. 2002;30:233–237. doi:10.1038/ng826.
32. Dyer SC, Austine-Orimoloye O, Azov AG, Barba M, Barnes I, Barrera-Enriquez VP, et al. Ensembl 2025. Nucleic Acids Res. 2025;53:D948–D957. doi:10.1093/nar/gkae1071.
33. Cerezo M, Sollis E, Ji Y, Lewis E, Abid A, Bircan KO, et al. The NHGRI-EBI GWAS Catalog: standards for reusability, sustainability and diversity. Nucleic Acids Res. 2025;53:D998–D1005. doi:10.1093/nar/gkae1070.
34. Elsworth B, Lyon M, Alexander T, Liu Y, Matthews P, Hallett J, et al. The MRC IEU OpenGWAS data infrastructure. bioRxiv. 2020:2020.08.10.244293. doi:10.1101/2020.08.10.244293.

## Figure legends

**Figure 1. Study design and evidence roles.** Swedish shotgun-metagenomic GWASs supplied primary forward exposures and reverse outcomes. FinnGen R12 was the primary forward outcome. Solid arrows denote primary analyses; dashed arrows denote parallel HUNT exposure-cohort analyses; dotted arrows denote alternative ED outcome sensitivities. The HUNT same-SNP and HUNT-selected MR paths are parallel. Each alternative outcome used a separate 230-trait BH family with non-estimable rows at P=1. European and cross-ancestry outcomes include FinnGen; African ancestry does not, but remains ancestry-transfer evidence. Eligibility and multiplicity rules were defined before screening; cross-trait LD compression and phenotype annotation were targeted post hoc analyses triggered by the alternative-outcome signals. ED, erectile dysfunction; GWS, genome-wide significant; IV, instrumental variable.

**Figure 2. Ranked P values and predefined multiplicity boundaries.** Observed P values are ranked for (a) 230 forward tests and (b) 1 572 reverse tests. BH 5% boundaries use the complete denominators. The horizontal lines show nominal P=0.05 and the global Bonferroni threshold 0.05/1 802. Twelve non-estimable forward tests are displayed at P=1 and remain in the primary denominator. No test passed FDR.

**Figure 3. Effect estimates, cross-cohort evaluation, and detectability of the forward analysis.** (a) Forest plot of seven nominal single-SNP estimates; none passed FDR. Peptococcaceae, Peptococcales, and Peptococcia form one nested taxonomic signal cluster with identical estimates. (b) Signed Swedish and HUNT SNP–exposure Z values for the two nominal exact-label traits. Their same-SNP HUNT exposure associations were weak; exposure scales differ, so effect magnitudes are not directly comparable. (c) IV-count distribution and 80%-power minimum detectable ORs per standardized trait unit. Presence traits use an approximate liability-scale standard deviation; this differs from the primary presence-trait MR log-odds exposure unit. CI, confidence interval; MDE, minimum detectable effect.

## Supplementary figure legends

**Supplementary Figure S1. Instrument architecture and strength.** Forward IV-count distribution, F-statistic summaries, and approximate R² by exposure scale.

**Supplementary Figure S2. P-value calibration and multiplicity sensitivities.** Descriptive forward and reverse QQ plots and forward BH boundaries. The n=225 unique-cluster boundary is nearly superimposable on the displayed boundaries and is not plotted separately.

**Supplementary Figure S3. Cross-cohort Swedish–HUNT same-SNP exposure evaluation.** Trait-level signed-Z comparison plus trait-level and unique-rsID direction-concordance estimates. Exact-binomial intervals are descriptive and do not model microbial-trait correlation.

**Supplementary Figure S4. Source-study-wide significance sensitivity.** Eligibility compression and ranked MR P values under the source-study thresholds.

**Supplementary Figure S5. Prespecified bounded mechanistic screening evidence map.** Planned, estimable, nominal, and FDR-significant counts and minimum q values across seven complete testing families.

**Supplementary Figure S6. Locus and ancestry structure of the 2025 ED outcome sensitivities.** (a) Signed standardized outcome statistics for the eight European trait-level associations surviving FDR correction across FinnGen, European, African-ancestry, and cross-ancestry outcomes; effect magnitude is not clinically comparable across scales. (b) Evidence flow from eight trait rows to three high-LD lead SNPs and one chr2q21 locus, with a separate African-ancestry coverage summary. Per-trait clumping allowed correlated variants across different microbial traits; European LD was applied only in the targeted post hoc audit. The compression is descriptive and does not define a locus-level P or q.

## Table titles and footnotes

**Table 1. GWAS sources and analytical roles.** The 2025 European and cross-ancestry analyses include FinnGen; the African-ancestry stratum does not. HUNT is an independent exposure cohort, but FinnGen remains the MR outcome; neither the legacy exploratory analysis nor the same-SNP lookup constitutes independent MR replication.

**Table 2. Nominal forward gut microbial trait–ED associations.** Presence-trait ORs are per one-unit increase in genetically predicted log odds of microbial presence; the abundance OR is per one RIN-standardized unit. These are seven nominal trait-level associations, not seven independent causal taxa; none survived FDR correction. The three Peptococcaceae-related traits are nested and have identical estimates. Swedish presence and HUNT normalized relative-abundance effects are not directly comparable. The two focal exact-label HUNT GWASs had no genome-wide-significant instruments; legacy 23-SNP and 20-SNP analyses used P<1×10⁻⁵ and were exploratory. All seven Swedish estimates were single-SNP Wald ratios.
