# Bidirectional Mendelian randomization of gut microbiota and erectile dysfunction with independent replication and multiplicity control

Short title: Gut microbiota and erectile dysfunction Mendelian randomization

## Abstract

Mendelian randomization studies have linked several gut microbial taxa to erectile dysfunction, often without independent replication. We performed bidirectional two-sample Mendelian randomization using shotgun-metagenomic genome-wide association studies of 1,572 microbial traits in 16,017 Swedish adults, exact-label validation in the Norwegian HUNT study, FinnGen R12 erectile dysfunction (2,886 cases and 215,272 controls), and a 2025 multi-ancestry meta-analysis as a known-overlap sensitivity source. Instruments met P<5×10−8, F>10, and ancestry-matched clumping at r²<0.001. Direction-specific Benjamini–Hochberg false-discovery rates were controlled at 5%. Of 230 eligible forward traits, 218 were estimable and seven were nominally associated; none survived correction (minimum q=0.9416). Both nominal traits with exact HUNT matches failed validation (P=0.4273 and P=0.1752). Reverse analysis used 24 independent erectile-dysfunction instruments across 1,572 microbial outcomes. Seventy-seven estimates were nominally significant, but none survived correction (minimum P=0.001861; minimum q=0.9673). These results do not support a robust causal association in either direction under the tested instruments and populations. Sparse forward instruments and incomplete taxonomic matching mean that small or taxon-specific effects cannot be excluded.

Keywords: erectile dysfunction; gut microbiome; Mendelian randomization; FinnGen; HUNT; multiple testing

## Introduction

Erectile dysfunction (ED) is a common, multifactorial disorder with vascular, metabolic, neurological, hormonal, and psychological determinants.[1] Gut microbial composition has been proposed as an additional contributor because dysbiosis may accompany systemic inflammation, insulin resistance, obesity, and endothelial dysfunction.[2,3] These biological links are plausible, but conventional observational associations cannot reliably distinguish causal effects from confounding, reverse causation, medication use, diet, or other host factors.

Several two-sample Mendelian randomization (MR) studies have reported nominal associations between microbial taxa and ED.[4–9] Most used the same 16S ribosomal RNA-based MiBioGen exposure resource and the same earlier European ED genome-wide association study (GWAS),[4,5] while the reported taxa have varied across analyses. Relaxed instrument thresholds and dense taxon-wide screening can increase the number of estimable associations, but they also heighten vulnerability to weak instruments, winner's curse, and false-positive selection when multiplicity and independent replication are not treated as primary evidential gates.

Two recent developments permit a more stringent reassessment. First, coordinated shotgun-metagenomic GWASs in Swedish cohorts and the Norwegian Trøndelag Health Study (HUNT) provide higher-resolution microbial phenotypes with independent Nordic replication.[11,12] Second, FinnGen R12 and a substantially larger multi-ancestry ED GWAS provide updated outcome and reverse-exposure data.[13,14] We therefore performed an error-controlled bidirectional MR study that froze eligibility before association screening, separated the forward and reverse testing families, required genome-wide-significant instruments, and treated known sample overlap as sensitivity evidence rather than independent validation.

## Materials and methods

### Study design and reporting

This summary-data study followed the STROBE-MR reporting framework.[10] The analysis protocol, eligibility rules, effect-scale restrictions, replication gates, and stopping decision were specified before inspection of MR association P values. Figure 1 summarizes the primary bidirectional evidence geometry. All tests were two-sided.

### GWAS data sources

Forward exposures were 1,572 microbial presence, abundance, higher-taxonomic, and diversity traits from harmonized shotgun metagenomes in 16,017 adults of European ancestry from four Swedish population studies.[11] The source study used Genome Taxonomy Database labels and GRCh37 coordinates. Independent exposure validation used matching HUNT GWASs in up to 12,652 Norwegian participants.[12] Exact biological labels were required; no fuzzy taxonomic reassignment was permitted.

The primary forward outcome was FinnGen R12 ED, comprising 2,886 cases and 215,272 controls of Finnish ancestry.[13] The phenotype was sex-specific and based on repeated purchases of phosphodiesterase-5 inhibitor medication after exclusion of pulmonary-hypertension indications. Estimates were log odds and could therefore be exponentiated as odds ratios. The 2025 ED study meta-analyzed European (136,867 cases and 776,327 controls), African-ancestry (51,599 cases and 73,716 controls), and cross-ancestry (188,466 cases and 850,043 controls) samples.[14] Its public files contained METAL Z statistics and weights; we analyzed them only on the standardized Z/√weight scale. Because FinnGen contributed to this meta-analysis, these data were treated as high-power, known-overlap sensitivity sources and not as independent outcome replication (Table 1).

### Instrument construction and harmonization

Microbial instruments were required to reach P<5×10−8, have an F statistic >10, and remain independent after ancestry-matched linkage-disequilibrium clumping at r²<0.001 within 10,000 kb. Clumping used 503 European participants from the 1000 Genomes Project Phase 3 GRCh37 reference panel.[15] PLINK 2.0 was used for variant processing and clumping.[16]

GRCh37 microbial variants and GRCh38 ED variants were joined by rsID and allele identity; chromosome concordance was checked independently, and coordinates from different builds were not compared directly. Multiallelic rsIDs required a unique allele-compatible outcome record. Palindromic variants were retained only when effect-allele frequencies in both datasets gave a unique orientation, both minor-allele frequencies were ≤0.42, and the frequency difference was ≤0.10.

For reverse MR, genome-wide-significant variants from the European 2025 ED meta-analysis were mapped to the same European linkage-disequilibrium reference and clumped under the identical parameters. Reverse effects were retained on the source study's standardized exposure scale and were not interpreted as odds ratios.

### MR estimation, sensitivity analyses, and multiplicity

One-instrument associations used the Wald ratio. Associations with multiple instruments used multiplicative random-effects inverse-variance weighting with the residual scale bounded below at one.[17] Weighted-median,[18] MR-Egger,[19] and robust adjusted profile score (MR-RAPS)[20] estimates were prespecified when their instrument-count requirements were met. MR-RAPS estimates with non-convergence or multiple-root warnings were recorded as failures. Steiger directionality[21] and MR-PRESSO[22] were prespecified for multiplicity-screened candidates when estimable.

Eligibility was frozen without reference to association P values. The 230 forward tests and 1,572 reverse tests formed separate Benjamini–Hochberg families controlled at a 5% false-discovery rate.[23] A strict cross-direction threshold was 0.05/(230+1,572)=2.774695×10−5. A forward association could be called replicated only if it passed forward false-discovery-rate control; had an exact HUNT match with a same-direction P<0.05 estimate and a non-null 95% confidence interval; showed concordance with a prespecified robust estimator when estimable; and had no supported direction reversal or severe unresolved horizontal pleiotropy. Reverse results were designated sensitivity analyses and could not receive a replicated label.

### Prespecified mechanistic extension

After the primary analysis was frozen, we specified a bounded supplementary analysis of inflammation and endothelial injury as potential intermediates. Five HUNT KEGG modules (M00080, M00091, M00136, M00530, and M00569) were selected on biological rationale and genome-wide instrument eligibility without reference to ED association P values. Each had one clumped P<5×10−8, F>10 instrument. The seven nominal taxonomic results from the primary screen were prohibited as a selection filter.

The mediator panels comprised all 40 circulating cytokines from a meta-GWAS of up to 74,783 participants[25] and nine prespecified cardiovascular proteins from SCALLOP (E-selectin, ESM-1, PECAM-1, TIE2, thrombomodulin, LOX-1, VEGF-A, U-PAR, and t-PA; up to 30,931 participants).[26] Mediator-to-ED analyses used cis-pQTLs. For cytokines, cis instruments were limited to the 19 leads classified as cis by the source article; for endothelial proteins, cis was defined as the encoding gene plus 300 kb on either side in GRCh37. The cytokine source had known partial overlap with FinnGen through FINRISK, whereas overlap between the SCALLOP cohorts, HUNT, and FinnGen remained possible; both panels were therefore screening sources rather than independent mechanistic confirmation.

Seven testing families were frozen: microbial function-to-ED (5 tests), cytokine-to-ED (40), endothelial protein-to-ED (9), microbial function-to-cytokine (200), microbial function-to-endothelial protein (45), cytokine indirect effects (200), and endothelial indirect effects (45). Each family used Benjamini–Hochberg control at 5%, with non-estimable rows retained at P=1. Indirect effects were calculated as the product of the two MR coefficients; delta-method P values were labelled sensitivity-only when overlap covariance was unknown. A pathway could be considered compatible with mediation only if both component effects and the product passed their respective false-discovery-rate gates, source independence was acceptable, directions were coherent, and locus-level colocalization supported the molecular association. Colocalization was triggered only after both component gates; proportion mediated was prohibited unless the corresponding total effect also survived correction.

### Software, reproducibility, and large-language-model use

Analyses were performed in R 4.5.1 using a project-specific locked environment and a pinned PLINK 2.0 executable. Raw inputs, normalized intermediates, code, and final outputs were bound by SHA-256 receipts; raw GWAS files were never modified. OpenAI Codex was used after statistical results were frozen for language editing, document generation, and code-assisted consistency checking. It was not used to select traits, set analytical thresholds, or adjudicate statistical significance. All substantive decisions, numerical results, and manuscript statements were verified by the authors.[24]

## Results

### Instrument and harmonization geometry

Of 1,572 Swedish microbial traits, 230 had at least one eligible genome-wide-significant, strong, clumped instrument. After harmonization with FinnGen, 218 traits were estimable and 12 lacked a usable outcome match. Among estimable forward analyses, 194 (89.0%) used one instrument, 18 used two, one used three, and five used four. Ninety-seven of the 230 forward traits had an exact HUNT label match.

The European ED GWAS supplied 479 genome-wide-significant variants for reverse analysis. Of these, 437 mapped by rsID, chromosome, and alleles to the European reference panel; clumping retained 24 independent instruments with a minimum F statistic of 30.21. Harmonization across 1,572 microbial outcomes retained 24,794 variant–trait rows, leaving 15–17 instruments per outcome. One frequency-unresolvable palindromic variant was excluded per outcome, and no allele mismatch was detected.

### Forward gut microbiota-to-ED analysis

Seven of 218 estimable forward effects had nominal P<0.05 (Table 2), compared with 10.9 expected by chance among 218 tests at α=0.05. All seven were one-instrument Wald estimates. None survived false-discovery-rate control; the smallest P value was 0.007196 and the minimum q value was 0.9416 (Figure 2a). No forward effect crossed the strict global threshold.

The two nominal traits with exact HUNT matches were *Fimisoma avicola* and UBA644 sp900547165. Their HUNT-based estimates did not validate (P=0.4273 and P=0.1752, respectively), although the point estimates had the same direction as the Swedish estimates. The remaining five nominal traits lacked an exact HUNT label match and were not reassigned approximately. Consequently, no forward association satisfied the prespecified replication rule.

### Reverse ED-to-gut microbiota analysis

All 1,572 reverse primary effects were estimable. Seventy-seven had nominal P<0.05, compared with 78.6 expected by chance at α=0.05, but none survived the reverse false-discovery-rate family (minimum P=0.001861; minimum q=0.9673; Figure 2b). No reverse effect crossed the strict global threshold. Across 6,288 method-specific rows, 6,184 estimates were obtained; 104 MR-RAPS rows were retained as explicit failures under the prespecified warning policy. The final frozen decision was therefore no-go for a positive causal claim in either direction.

### Mechanistic extension

All five microbial function-to-ED total effects were estimable, but none survived the five-test family (minimum P=0.1139; minimum q=0.4822). In the cytokine arm, 18 of 40 mediator-to-ED effects, 169 of 200 function-to-cytokine effects, and 80 of 200 indirect effects were estimable; none survived correction (minimum q values 1.0000, 0.9456, and 1.0000, respectively). CCL11 was the only nominal cytokine-to-ED result (P=0.0358; q=1.0000), but its cis lead failed the prespecified source-heterogeneity sensitivity and the source had known partial FinnGen overlap.

For endothelial proteins, 1,476 genome-wide-significant cis candidates yielded 11 clumped instruments across seven of nine proteins after GRCh37 reference mapping; PECAM-1 and t-PA were non-estimable. Seven of nine protein-to-ED effects, all 45 function-to-protein effects, and 35 of 45 indirect effects were estimable, with no false-discovery-rate signal (minimum q=0.3953, 0.4894, and 1.0000, respectively). No pathway passed both component gates, so colocalization was not triggered and no proportion mediated was calculated. The prespecified decision was to stop before broad metabolite or immune-cell expansion (Supplementary Data 1).

## Discussion

In this bidirectional analysis, neither genetically proxied gut microbial traits nor genetic liability to ED showed an association that survived direction-specific multiplicity control. The forward screen produced fewer nominal findings than expected under a uniform null distribution, and all seven were single-instrument estimates. The two nominal traits that could be tested using exact HUNT labels failed independent exposure validation. In the reverse direction, the number of nominal results was almost identical to the chance expectation, and the minimum adjusted P value remained close to one. Taken together, the data do not support elevating any observed association to a robust causal finding.

The supplementary mechanism analysis did not identify evidence that circulating cytokines or endothelial-injury proteins carried an effect from the five selected microbial functions to ED. This conclusion is stronger than a scan of nominal mediator P values because the exposure set and all seven family denominators were frozen, non-estimable tests were retained, and no pathway advanced without jointly satisfying its component gates. In particular, CCL11 should not be interpreted as a mediator: its nominal association had q=1, arose in a known-overlap source, and was removed by the source-heterogeneity sensitivity. The stopping rule also avoided an outcome-driven expansion into broad metabolite and immune-cell panels after the prespecified mediator families were negative.

This result differs from several previous gut microbiota–ED MR reports that highlighted small sets of nominal taxa.[6–9] The discrepancy should not be read as a direct refutation of every historical taxon, because exposure taxonomies and measurement platforms are not one-to-one. Earlier studies largely used 16S-based MiBioGen traits,[4] whereas the present study used species-resolved shotgun metagenomes and Genome Taxonomy Database labels.[11,12] The more consequential differences are evidential: we required genome-wide significance rather than a relaxed exposure threshold, froze the full testing denominator, controlled false discovery rates separately by direction, demanded exact independent exposure validation, and prevented a known-overlap ED meta-analysis from being misclassified as replication. These choices reduce the opportunity for selective reporting of isolated P<0.05 results.

The absence of a corrected association is informative for prioritization but is not proof that the gut microbiome is irrelevant to erectile physiology. Host genetic effects on microbial composition are generally modest,[4,11,12] and 89% of estimable forward traits were represented by one instrument. Such estimates can be statistically strong yet remain vulnerable to variant-specific horizontal pleiotropy that cannot be diagnosed empirically with one SNP. The present analysis therefore rules out neither small effects nor effects of microbial functions, strain-level features, metabolites, ecological interactions, or interventions that are poorly proxied by germline variants.

Several additional limitations define the scope of inference. Only 97 of 230 forward traits had an exact HUNT match, so independent validation coverage was incomplete. Presence and relative-abundance phenotypes can differ in scale even when their biological label matches; validation was therefore interpreted by direction and uncertainty, not by equality of effect magnitude. FinnGen's medication-purchase phenotype preferentially captures recognized and treated ED and may not represent untreated or psychogenic disease. The larger ED outcome sensitivity datasets overlap FinnGen and cannot supply independent outcome replication. In the mechanistic extension, all five microbial-function estimates were single-instrument Wald ratios, cytokine data partially overlapped FinnGen, and SCALLOP overlap remained unresolved; covariance-free product standard errors were consequently sensitivity estimates rather than independent mediation tests. Analyses were dominated by European-ancestry participants, and ancestry transfer for microbiome instruments remains uncertain. Finally, unavailable prevalence information and exposure allele frequencies prevented a defensible binary-outcome Steiger calculation for some planned comparisons; unavailable diagnostics were not treated as favorable evidence.

The main strength of this study is its deliberately conservative evidence geometry. Eligibility and effect scales were frozen before screening; genome-build differences were handled without coordinate mixing; ancestry-matched clumping, exact taxonomic matching, warning-aware robust estimation, full-family multiplicity correction, and cryptographic receipts were used throughout. Future work should prioritize larger ancestry-diverse shotgun-metagenomic GWASs, published cross-cohort taxonomic crosswalks, independent ED datasets that do not overlap discovery cohorts, and instruments for microbial functions or metabolites. Within the present data and assumptions, no gut microbial trait warrants causal or therapeutic prioritization for ED on MR evidence alone.

## Data availability

The GWAS summary statistics analyzed in this study are available from the GWAS Catalog, FinnGen R12, the 1000 Genomes Project reference release, Zenodo, and the cited source studies under their respective terms. Source accessions, URLs, checksums, frozen result tables, and data dictionaries, including the complete mechanistic-extension results, are supplied in Supplementary Data 1. The primary v0.1 analysis code, hash receipts, frozen summary results, and manuscript-associated materials are publicly archived in Zenodo at https://doi.org/10.5281/zenodo.21456671 (version 0.1.0; all-version concept DOI: https://doi.org/10.5281/zenodo.21456670). The versioned mechanistic-extension code and receipts are maintained in the development repository at https://github.com/DuXC/gut-microbiome-ed-mr. Third-party raw summary-statistic files are not redistributed where source terms do not permit redistribution.

## Acknowledgements

We acknowledge the participants and investigators of the FinnGen study. We also thank the participants and investigators of the Swedish microbiome cohorts, the HUNT study, All of Us, the UK Biobank, the Million Veteran Program, the Estonian Biobank, and the Partners HealthCare Biobank whose summary data made this work possible.

## Author contributions

X.D.: Conceptualization, methodology, software, formal analysis, data curation, visualization, project administration, and writing—original draft. S.T.: Investigation, data curation, validation, and writing—review and editing. K.X.: Investigation, data curation, validation, and writing—review and editing. Y.Z.: Methodology, formal-analysis verification, validation, and writing—review and editing. M.C.: Resources, clinical interpretation, supervision, and writing—review and editing. C.L.: Conceptualization, supervision, funding acquisition, and writing—review and editing. C.S.: Conceptualization, methodology, supervision, validation, project administration, funding acquisition, and writing—review and editing. All authors reviewed and approved the final manuscript and accept accountability for the work.

## Funding

This work was supported by the Jiangsu Provincial Research Project on Traditional Chinese Medicine and Integrated Chinese-Western Medicine (No. ZXFZ2026021; awarded to Chao Sun) and the China Postdoctoral Science Foundation (No. 2024M750457; awarded to Chunhui Liu). The funders had no role in study design, data collection, analysis, interpretation, manuscript preparation, or the decision to submit the work for publication.

## Ethical approval

No new ethical approval or participant consent was required because this study used only publicly available, deidentified GWAS summary statistics. Ethical approval and informed consent were obtained by the investigators of each contributing study as described in the original publications.

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
22. Verbanck M, Chen CY, Neale B, Do R. Detection of widespread horizontal pleiotropy in causal relationships inferred from Mendelian randomization between complex traits and diseases. Nat Genet. 2018;50:693–698. doi:10.1038/s41588-018-0099-7.
23. Benjamini Y, Hochberg Y. Controlling the false discovery rate: a practical and powerful approach to multiple testing. J R Stat Soc Series B Stat Methodol. 1995;57:289–300. doi:10.1111/j.2517-6161.1995.tb02031.x.
24. Burgess S, Davey Smith G, Davies NM, Dudbridge F, Gill D, Glymour MM, et al. Guidelines for performing Mendelian randomization investigations. Wellcome Open Res. 2020;4:186. doi:10.12688/wellcomeopenres.15555.2.
25. Konieczny MJ, Omarov M, Zhang L, Malik R, Richardson TG, Baumeister SE, et al. The genomic architecture of circulating cytokine levels points to drug targets for immune-related diseases. Commun Biol. 2025;8:34. doi:10.1038/s42003-025-07453-w.
26. Folkersen L, Gustafsson S, Wang Q, Hansen DH, Hedman ÅK, Schork A, et al. Genomic and drug target evaluation of 90 cardiovascular proteins in 30,931 individuals. Nat Metab. 2020;2:1135–1148. doi:10.1038/s42255-020-00287-2.

## Figure legends

**Figure 1. Study design and evidence roles.** The forward analysis used genome-wide-significant, strong, ancestry-matched microbial instruments from Swedish shotgun-metagenomic GWASs and FinnGen R12 ED as the primary outcome. Exact-label HUNT traits provided independent exposure validation. The 2025 ED meta-analysis was retained as a known-overlap, scale-specific sensitivity source. Reverse MR used independent European ED instruments and 1,572 Swedish microbial outcomes. GWS, genome-wide significant; HUNT, Trøndelag Health Study; IV, instrumental variable; MR, Mendelian randomization.

**Figure 2. Ranked P values and prespecified multiplicity boundaries.** Observed P values are plotted by ascending rank for (a) 230 forward gut microbiota-to-ED tests and (b) 1,572 reverse ED-to-gut microbiota tests. The light horizontal line marks nominal P=0.05. The diagonal dashed curve is the Benjamini–Hochberg 5% critical boundary at each rank; an observed curve must cross above it on the −log10 scale to generate a rejection. The horizontal dotted line is the strict global Bonferroni threshold of 2.774695×10−5. No test crossed either multiplicity boundary. Twelve non-estimable forward tests are placed at P=1 for display only and were retained in the frozen family denominator.

## Table titles and footnotes

**Table 1. GWAS sources and their prespecified analytical roles.** Sample sizes are source-specific. The 2025 ED meta-analysis includes FinnGen and therefore cannot be considered independent outcome replication. The cytokine meta-GWAS has known partial FinnGen overlap through FINRISK, and overlap of the SCALLOP mediator source with HUNT or FinnGen remains possible or unresolved; both mediator panels are screening sources.

**Table 2. Nominal forward gut microbiota-to-erectile-dysfunction associations.** Odds ratios are Wald-ratio estimates per source-defined unit of the microbial trait. All seven associations used one instrument and none survived the 230-test false-discovery-rate family. HUNT estimates are shown only for exact biological-label matches; their exposure scales differ from the Swedish presence phenotypes, so effect magnitudes should not be compared directly. CI, confidence interval; FDR, false-discovery rate; HUNT, Trøndelag Health Study; NA, no exact label match; OR, odds ratio.
