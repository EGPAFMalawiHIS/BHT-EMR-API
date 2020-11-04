# Changelog

This file tracks all changes to the BHT-EMR-API. Changes are grouped under
the following tags: `Fixed`, `Added`, `Deprecated`, and `Removed`. All bug
fixes are listed under `Fixed`. New features and any other additions
are placed under `Added`. For all features marked for removal in a future
version, `Deprecated`, is used. Anything removed in a particular version
is placed under `Removed`.

For versioning, BHT-EMR-API follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
In short, a version number is of the following format `major.minor.patch`
(eg 4.10.7). The patch number changes whenever minor bugs are fixed. The
minor number changes with new backward compatible features. The major
number changes with major changes that completely break backwards
compatibility (examples of this include major architectural changes).

## Unreleased

### Added

### Fixed

- Fixed leak of User.current and Location.current across threads.
- ART: Previously on treatment patients who are currently not on treatment were
  not being switched back to on treatment upon ARV dispensation.
- ART Stock: Fixed resetting of drug stock to delivered quantity on voiding
  of dispensation.

### Deprecated

### Removed

## [4.10.15] - 2020-10-21

### Added

- ART: Granules and Tablets disaggregation for 9P and 11P on cohort report.
- Visit report drilldown

### Fixed

- ART: Cohort report crash when cohort is run in quarters without any patients
  that have an 'On Treatment' status/outcome.

## [4.10.14] - 2020-10-16

### Added

- ART: Optimisations of slow running data cleaning tools: Missing ART reason
- ART: Client visit report

### Fixed

- Missing 'Antiretrovirals' concept set member in metadata: LPV/r Granules.
- Missing clinics in metadata: Umunthu Foundation Clinic, Kameza Macro, Chilaweni.
- ART: Undercounting of female pregnant in cohort due to patient pregnant
  observations without an answer.
- ART: Counting of patients that started treatment before the last 6 months
  in TB Prev.
- ART: Double counting of Re-initiated and Transfer ins on cohort (NOTE:
  This was more of a data integrity issue as opposed to an actual bug in
  the system. Some patients had multiple *last taken ART* observations
  with different answers that fit both Re-initiated and Transfer in
  classifications).