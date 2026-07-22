# Bidirectional Mendelian randomization of gut microbial traits and erectile dysfunction with cross-cohort exposure validation and multiplicity control

Short title: Gut microbial traits and erectile dysfunction

## Abstract

Prior Mendelian randomization studies have reported gut microbial traits associated with erectile dysfunction (ED), often from relaxed instruments and nominal tests. We reassessed this relationship bidirectionally using 1 572 Swedish shotgun-metagenomic traits, FinnGen R12 ED (2 886 cases; 215 272 controls), a 2025 ED genome-wide association study, and exact-label HUNT data. Primary microbial instruments required P<5×10⁻⁸ and F>10; false-discovery rates (FDRs) used complete predefined families. Among 230 eligible forward traits, 218 were estimable and seven had nominal P<0.05, but none passed FDR (minimum q=0.942). No reverse association passed FDR among 1 572 traits. Same-SNP HUNT lookup was available for 97 exact-label traits; 76 directions were concordant, but the two nominal matched traits had weak HUNT associations and no HUNT genome-wide-significant instruments. Their earlier HUNT-selected analyses used exploratory P<1×10⁻⁵ instruments. At the forward-family threshold, the median 80%-power minimum detectable odds ratio was 2.89, indicating limited sensitivity to smaller effects. No association met the predefined multiplicity-controlled criteria for a robust causal interpretation. Limited instrument coverage and extensive single-variant estimation mean that small or feature-specific effects cannot be excluded.

Keywords: erectile dysfunction; gut microbiome; Mendelian randomization; FinnGen; HUNT; multiple testing

## Introduction

Erectile dysfunction (ED) is a multifactorial disorder with vascular, metabolic, neurological, hormonal, and psychological determinants.[1] Gut dysbiosis could plausibly influence erectile physiology through insulin resistance, systemic inflammation, microbial metabolites, and endothelial dysfunction, but observational associations remain vulnerable to confounding, medication use, diet, and reverse causation.[2,3] Recent IJIR studies illustrate the clinical interest in microbiota, inflammation, and metabolic markers in ED.[2,29]

Several two-sample Mendelian randomization (MR) studies have reported nominal gut microbial taxa associated with ED.[4–9] Most used 16S-based MiBioGen traits, P<1×10⁻⁵ instruments, and an earlier European ED genome-wide association study (GWAS).[4,5] Differences in selected taxa, sparse instruments, incomplete multiplicity control, and limited independent evaluation make reproducibility uncertain; these limitations do not imply that the earlier findings are necessarily false.

Shotgun-metagenomic GWASs from Swedish cohorts and the Norwegian Trøndelag Health Study (HUNT), together with FinnGen R12 and a larger 2025 ED GWAS, permit a stricter reassessment.[11–14] We therefore tested both causal directions using genome-wide-significant instruments, complete testing denominators, cross-cohort same-SNP exposure validation, sensitivity analyses for source-study thresholds and multiplicity, and an overlap-aware interpretation of the available ED and mechanistic datasets.

## Materials and methods

### Study design and data sources

This summary-data study followed STROBE-MR.[10] Eligibility and multiplicity rules were finalized before association screening. Swedish GWASs comprised 1 572 microbial presence, rank-based inverse-normal (RIN) abundance, higher-taxonomic, functional, and diversity traits in 16 017 European-ancestry adults.[11] HUNT provided exact-label normalized relative-abundance GWASs in up to 12 652 Norwegian participants.[12] No fuzzy taxonomic matching was used.

The primary forward outcome was FinnGen R12 ED (2 886 cases; 215 272 controls), defined by repeated phosphodiesterase-5-inhibitor purchases after exclusion of pulmonary-hypertension indications.[13] A 2025 meta-GWAS supplied European (136 867 cases; 776 327 controls), African-ancestry (51 599 cases; 73 716 controls), and cross-ancestry (188 466 cases; 850 043 controls) sensitivity outcomes and the reverse ED exposure.[14] Because FinnGen contributed to that study, these forward sensitivities were not independent outcome replications. Their METAL Z/√weight scale was used only for statistical screening and was not interpreted as ED log odds or a clinically quantifiable risk increment (Table 1).

### Instruments, harmonization, and effect scales

Primary microbial instruments required P<5×10⁻⁸, F>10, and European linkage-disequilibrium clumping at r²<0.001 within 10 000 kb using 503 European participants from 1000 Genomes Phase 3.[15,16] GRCh37 microbial and GRCh38 ED records were joined by rsID, chromosome, and allele compatibility without direct coordinate comparison. Palindromic and multiallelic records were retained only when orientation was unique. Presence-trait estimates are reported as the ED odds ratio (OR) per one-unit increase in the genetically predicted log odds of microbial presence; RIN abundance or diversity estimates are per source-standardized unit. Reverse effects retain the Z/√weight exposure scale and support directionality screening only.

The source paper used study-wide thresholds of 1.7×10⁻⁸ for diversity, 5.4×10⁻¹¹ for species and higher taxa, and 4.3×10⁻¹⁰ for functions.[11] We repeated forward selection, clumping, harmonization, and MR at those trait-class thresholds as a sensitivity analysis.

### MR estimation, multiplicity, and diagnostic analyses

Single-variant effects used Wald ratios; multi-variant effects used multiplicative random-effects inverse-variance weighting. Weighted median, MR-Egger, and MR-RAPS were run when their instrument requirements were met, with warnings and failures retained explicitly.[17–20] Steiger directionality and MR-PRESSO were candidate-triggered analyses; absence of an estimable diagnostic was never treated as favorable evidence.[21,22]

The primary Benjamini–Hochberg (BH) families contained all 230 eligible forward and 1 572 reverse tests, with non-estimable tests retained at P=1.[23] The cross-direction Bonferroni threshold was 0.05/1 802. Sensitivities repeated forward BH among 218 estimable tests and after collapsing only rows with identical SNPs, exposure and outcome coefficients, standard errors, P values, and nested taxonomy into 225 unique signal clusters. Peptococcaceae, Peptococcales, and Peptococcia were one such nested, identical cluster.

### Cross-cohort validation and pleiotropy annotation

For every exact-label HUNT match, the Swedish lead SNP was queried at the same GRCh37 position, allele-aligned, and compared using signed Z and direction; raw coefficients were not compared because Swedish presence and HUNT normalized-abundance scales differ. Direction concordance used a descriptive exact-binomial interval that does not model correlation among microbial traits. Separately, the legacy analysis that selected HUNT-specific SNPs at P<1×10⁻⁵ and paired them with FinnGen was retained as an exploratory exact-label HUNT sensitivity analysis, not independent MR replication.

The seven nominal forward rows were audited at the five unique SNPs using Ensembl and exact-rsID GWAS Catalog queries on 22 July 2026. The annotation covered metabolic, inflammatory, immune, dietary, medication, smoking, and cardiovascular traits and proximity within 1 Mb to FUT2, LCT, or ABO. Unretrieved associations were recorded as “not identified”, not absent.

### Power and minimum detectable effects

For RIN traits, instrument R² was approximated as Σ2EAF(1−EAF)β². Presence traits used a liability-scale approximation from the log-odds coefficient, EAF, sample size, and source-reported prevalence, with prevalence±0.10 scenarios.[28] Using 2 886 cases and 215 272 controls, the binary-outcome mRnd approximation was root-solved for the OR giving 80% power at α=0.05, 0.05/230, and 0.05/1 802.[27] EAF, beta, standard error, P, sample size, assumptions, and attained-power checks are supplied per instrument and trait.

### Prespecified bounded mechanistic screening

The two-step screening evaluated five microbial functions, 40 cytokines, and nine endothelial proteins in seven complete families: 5 function-to-ED, 40 cytokine-to-ED, 9 protein-to-ED, 200 function-to-cytokine, 45 function-to-protein, 200 cytokine indirect-effect, and 45 protein indirect-effect tests.[25,26] Non-estimable rows remained at P=1. Product estimates used delta-method standard errors and were not called causal mediation. A mediation-compatible interpretation required both components and the indirect-effect family to pass FDR, direction consistency, acceptable data independence, and colocalization. For the source-heterogeneity sensitivity, cytokine cis leads with source meta-GWAS heterogeneity P<0.05 were excluded, their family P values set to 1, and BH recalculated; colocalization was triggered only if both component criteria passed.

### Software and reproducibility

Analyses used R and pinned PLINK executables in a versioned environment. Inputs and outputs were linked by SHA-256 provenance records; original GWAS files were not modified. OpenAI Codex assisted code review, language editing, document generation, and consistency checks after analytical criteria had been defined. It did not select traits or determine statistical significance; the authors verified all outputs and remain accountable for the work.[24]

## Results

### Primary bidirectional analyses

Of 230 forward-eligible traits, 218 were estimable; 194 (89.0%) used one SNP, 18 used two, one used three, and five used four (Figure 3c). Seven single-SNP Wald estimates had nominal P<0.05, but none passed the 230-test FDR (minimum P=0.00720; minimum q=0.9416; Table 2 and Figures 2–3). The three Peptococcaceae-related rows had identical estimates and represent one nested signal cluster, not three independent biological findings. Weighted median and MR-Egger were estimable for six traits each; MR-RAPS was estimable for 23 and failed explicitly for one. Steiger and MR-PRESSO were not triggered because no association passed FDR; the seven nominal estimates were all single-SNP.

The reverse analysis used 24 independent ED instruments and estimated all 1 572 microbial outcomes. Seventy-seven had nominal P<0.05, but none passed reverse-family FDR (minimum P=0.00186; minimum q=0.9673; Figure 2b). Across the 6 288 robust-method rows, 6 184 were estimated and 104 MR-RAPS rows retained explicit failures.

### Multiplicity, source-threshold, and ED-outcome sensitivities

No forward association passed estimable-only BH (n=218; minimum q=0.8925) or unique-signal-cluster BH (n=225; minimum q=0.9605). At source-study-wide thresholds, 27 traits remained eligible, 23 were estimable, four were non-estimable, and none had nominal P<0.05 (minimum P=0.1533; minimum q=1; Supplementary Figure S4).

The known-overlap 2025 ED sensitivities estimated 158 European, 108 African-ancestry, and 165 cross-ancestry traits. European and cross-ancestry analyses each contained eight FDR associations (minimum P=6.39×10⁻⁵; minimum q=0.00594), whereas the African-ancestry analysis contained none (minimum q=1). The European and cross-ancestry results substantially overlapped, retained the Z/√weight scale, and included FinnGen; they therefore did not override the primary outcome or constitute independent replication.

### Cross-cohort exposure validation and locus audit

All 97 exact-label Swedish lead SNPs were found and allele-compatible in HUNT. Seventy-six directions were concordant (78.4%; descriptive 95% CI 68.8%–86.1%; Supplementary Figure S3). The two nominal matched traits, *Fimisoma avicola* and UBA644 sp900547165, had no HUNT instrument at P<5×10⁻⁸. Same-SNP HUNT associations were weak (P=0.965, F=0.002, concordant; and P=0.671, F=0.180, discordant). The exploratory HUNT-selected analyses instead used 23 and 20 SNPs at P<1×10⁻⁵ and were also non-significant (P=0.427 and P=0.175). Thus, neither focal trait was validated.

The seven nominal rows mapped to five unique SNPs. Exact-rsID GWAS Catalog queries identified no listed association for four SNPs. rs62103891 was associated with programmed cell death protein 5 measurement (P=7×10⁻⁶⁴), creating a possible but unresolved pleiotropy concern. None was within 1 Mb of FUT2, LCT, or ABO (Supplementary Table S8).

### Detectability and mechanistic screening

Across 218 traits, approximate R² had a median of 0.00203 (IQR 0.00168–0.00274; range 0.00137–0.00760). Median 80%-power MDE ORs were 2.17 at α=0.05 (IQR 2.01–2.29; range 1.61–2.43), 2.89 at 0.05/230 (IQR 2.63–3.08; range 1.98–3.29), and 3.09 at 0.05/1 802 (IQR 2.81–3.29; range 2.09–3.53). Fifty-four traits could detect OR≥2 at nominal α, compared with one at the forward-family threshold and none globally (Figure 3c; Supplementary Table S5).

The bounded mechanistic workbook contained all 544 planned rows, including 185 non-estimable rows. No family produced an FDR association (minimum q by family 0.395–1.000; Supplementary Figure S5). CCL11-to-ED was nominal (P=0.0358; q=1) but its cis lead showed source heterogeneity (I²=86.8%; P=0.00587) and was excluded in the predefined sensitivity. No component pair jointly passed FDR, so colocalization was not triggered and no pathway received a mediation-compatible interpretation.

## Discussion

No association met the predefined multiplicity-controlled criteria for a robust causal interpretation in either direction. This conclusion was unchanged by estimable-only, nested-signal, or source-study-wide sensitivities. It describes the evidence from the tested instruments and datasets; it does not prove that gut microbial variation has no causal effect on ED.

Earlier microbiome–ED MR studies reported several nominal taxa, often using MiBioGen, P<1×10⁻⁵ instruments, and an earlier ED GWAS.[4–9] Our study differs in measurement platform, taxonomy, instrument threshold, testing denominator, and overlap handling. The IJIR microbiome MR report, for example, selected microbial instruments at P<1×10⁻⁵ and highlighted six nominal taxa.[8] These design differences, rather than a direct one-to-one refutation of historical taxa, explain why isolated P<0.05 results should not be assumed to reproduce across resources.

The MDE analysis clarifies what the negative result can and cannot exclude. At the forward-family threshold, the median detectable OR was 2.89, and only one trait had 80% power for an OR of 2. Accordingly, the study provides evidence against large effects for the best-instrumented traits but has little ability to exclude small or moderate effects. R² is approximate, particularly for presence traits: their liability-scale values depend on prevalence and do not create a unique clinically observed scale.

HUNT added an independent exposure cohort, not independent MR replication. Same-SNP direction concordance across exact labels was substantial, but correlated microbial traits make its binomial uncertainty descriptive. More importantly, the two nominal focal traits had weak same-SNP HUNT associations and no HUNT genome-wide-significant instruments. Their earlier HUNT MR estimates were based on exploratory, HUNT-selected P<1×10⁻⁵ sets and the same FinnGen outcome. Swedish presence and HUNT abundance effects also cannot be compared numerically.

Instrument architecture remains the principal limitation. Eighty-nine percent of estimable forward traits and all seven nominal rows used one SNP, precluding informative MR-Egger, heterogeneity, MR-PRESSO, or leave-one-out analyses at those loci. The annotation audit found one possible pleiotropic association and no catalogued association for four SNPs, but “not identified” is not evidence that pleiotropy is absent. Larger multi-instrument microbial GWASs and locus-level functional studies are required.

FinnGen's medication-purchase phenotype preferentially captures recognized and treated ED. The larger 2025 European and cross-ancestry sensitivities yielded corrected associations, but FinnGen overlap, overlapping European results, and the standardized screening scale prevent independent causal confirmation. Their disagreement with the primary outcome is therefore a reason for testing in a non-overlapping ED cohort, not for selecting post hoc taxa. The African-ancestry analysis had lower coverage and no FDR association; ancestry transfer of European microbial instruments remains uncertain.

Inflammation, insulin resistance, metabolites, and endothelial dysfunction remain biologically plausible in ED and are active topics in IJIR.[29,30] However, the bounded two-step screening found no pathway meeting its component criteria, and CCL11 failed source-heterogeneity sensitivity. We therefore do not describe this extension as formal causal mediation and did not expand it into unplanned metabolite, immune-cell, or pathway panels.

Clinically, no microbial trait should be prioritized as an ED treatment target from these MR results alone. Future studies need larger ancestry-diverse shotgun GWASs, standardized taxonomic crosswalks, independent non-overlapping ED outcomes, stronger instruments for microbial functions and metabolites, and colocalized multi-omic evidence. Until then, strict multiplicity control and explicit detectability limits are preferable to interpreting nominal taxa as established therapeutic targets.

## Data availability

GWAS summary statistics are available from the GWAS Catalog, FinnGen, 1000 Genomes, and the cited studies under their source terms. Source accessions, checksums, result tables, data dictionaries, and full v0.3 supplementary analyses accompany this submission. The development repository is https://github.com/DuXC/gut-microbiome-ed-mr. Versioned releases are archived under the Zenodo all-version concept DOI https://doi.org/10.5281/zenodo.21456670. This submission and its repository metadata are versioned v0.3.0; the matching version-specific DOI is linked from the concept record after deposition. Restricted third-party GWAS payloads are not redistributed.

## Acknowledgements

We thank the participants and investigators of FinnGen, the Swedish microbiome cohorts, HUNT, All of Us, UK Biobank, the Million Veteran Program, the Estonian Biobank, the Partners HealthCare Biobank, the cytokine meta-GWAS, and SCALLOP.

## Author contributions

X.D.: Conceptualization, methodology, software, formal analysis, data curation, visualization, project administration, and writing—original draft. S.T.: Investigation, data curation, validation, and writing—review and editing. K.X.: Investigation, data curation, validation, and writing—review and editing. Y.Z.: Methodology, formal-analysis verification, validation, and writing—review and editing. M.C.: Resources, clinical interpretation, supervision, and writing—review and editing. C.L.: Conceptualization, supervision, funding acquisition, and writing—review and editing. C.S.: Conceptualization, methodology, supervision, validation, project administration, funding acquisition, and writing—review and editing. All authors reviewed and approved the manuscript and accept accountability for the work.

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

## Figure legends

**Figure 1. Study design and evidence roles.** Swedish shotgun-metagenomic GWASs supplied primary forward exposures and reverse outcomes. FinnGen R12 was the primary forward outcome. Solid arrows denote primary analyses; dashed arrows denote the independent HUNT exposure cohort; dotted arrows denote the known-overlap 2025 ED sensitivities. HUNT same-SNP lookup compared exposure-association direction only. The legacy HUNT-specific MR sensitivity used exploratory P<1×10⁻⁵ instruments and was not independent replication. Eligibility and multiplicity rules were finalized before association screening. ED, erectile dysfunction; GWS, genome-wide significant; IV, instrumental variable.

**Figure 2. Ranked P values and predefined multiplicity boundaries.** Observed P values are ranked for (a) 230 forward tests and (b) 1 572 reverse tests. BH 5% boundaries use the complete denominators. The horizontal lines show nominal P=0.05 and the global Bonferroni threshold 0.05/1 802. Twelve non-estimable forward tests are displayed at P=1 and remain in the primary denominator. No test passed FDR.

**Figure 3. Effect estimates, cross-cohort validation, and detectability of the forward analysis.** (a) Forest plot of seven nominal single-SNP estimates; none passed FDR. Peptococcaceae, Peptococcales, and Peptococcia are nested traits with identical estimates. (b) Signed Swedish and HUNT SNP–exposure Z values for the two nominal exact-label traits. Their HUNT same-SNP instruments were weak and neither validated; exposure scales differ, so effect magnitudes are not directly comparable. (c) Instrument-count distribution and 80%-power MDE ORs at nominal, forward-family, and global thresholds. CI, confidence interval; MDE, minimum detectable effect.

## Table titles and footnotes

**Table 1. GWAS sources and analytical roles.** Sample size, ancestry, genome build, phenotype scale, overlap, instrument threshold, and evidence role are source-specific. The 2025 ED meta-analysis includes FinnGen and is not independent outcome replication. HUNT is an independent exposure cohort, but FinnGen remains the MR outcome.

**Table 2. Nominal forward gut microbial trait–ED associations.** Presence-trait ORs are per one-unit increase in genetically predicted log odds of microbial presence; the abundance OR is per one RIN-standardized unit. These are seven nominal trait-level rows, not seven independent causal taxa. The three Peptococcaceae-related traits are nested and have identical estimates. Swedish presence and HUNT normalized-abundance effects are not directly comparable. All seven estimates used one SNP and none passed FDR.
