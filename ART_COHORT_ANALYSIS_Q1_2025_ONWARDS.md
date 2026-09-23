# ART Cohort Report Analysis: 2025 Q1 Onwards

## Executive Summary
This document provides an analysis framework for three key ART cohort indicators since 2025 Q1:
1. **Cumulative Ever Registered** - Total HIV patients ever registered
2. **Total Alive and On ART** - Patients currently on active antiretroviral treatment
3. **Defaulted** - Patients who have discontinued treatment (>2 months overdue)

---

## Data Source & Architecture

### System Components
- **Backend**: BHT-EMR-API (Ruby on Rails)
- **Database**: MySQL with OpenMRS schema
- **Report Engine**: ArtService::ReportEngine
- **Temporal Tables**: 
  - `temp_earliest_start_date` - Enrollment data
  - `temp_patient_outcomes` - Outcome classification
  - `temp_patient_outcomes` - Current status tracking

### Report Generation Workflow
```
API Request (ProgramReportsController)
  ↓
ReportService.generate_report()
  ↓
ArtService::ReportEngine
  ↓
CohortBuilder.cohort() → CohortStruct
  ↓
Indicators calculated from temporary tables
  ↓
JSON response with quarterly data
```

---

## Indicator Definitions

### 1. Cumulative Ever Registered (`cum_total_registered`)

**Definition**: Total number of unique patients who have ever been enrolled in the HIV program from program inception through the end of the reporting period.

**Calculation Method**:
- Counts all unique `patient_id` entries in `temp_earliest_start_date`
- Uses earliest enrollment date (MIN) from all historical enrollments
- Includes patients with ANY status (on treatment, defaulted, deceased, transferred)

**SQL Logic**:
```sql
SELECT COUNT(DISTINCT patient_id)
FROM temp_earliest_start_date
WHERE date_enrolled <= '{{ end_date }}'
```

**Interpretation**:
- **Numerator**: All patients ever registered
- **Denominator**: N/A (absolute count)
- **Trend**: Should be monotonically increasing (can only add, not subtract)
- **Seasonality**: None expected (cumulative)

**Data Quality Checks**:
- Should never decrease quarter-to-quarter
- Rate of increase may vary by facility/program maturity
- Review for data entry errors if negative changes occur

---

### 2. Total Alive and On ART (`total_alive_and_on_art`)

**Definition**: Number of unique patients who are currently alive and actively taking antiretroviral therapy at the end of the reporting period.

**Eligibility Criteria**:
- At least one valid "On Antiretrovirals" state in patient_state
- Earliest ART start date ≤ end of reporting quarter
- Most recent patient state = "On Antiretrovirals" (not defaulted/deceased/stopped)
- Registered at current facility

**Calculation Method**:
- Queries `temp_patient_outcomes` table
- Filters for `moh_cum_outcome = 'On antiretrovirals'`
- Counts distinct patient_id values

**SQL Logic**:
```sql
SELECT DISTINCT patient_id
FROM temp_patient_outcomes
WHERE moh_cum_outcome = 'On antiretrovirals'
  AND patient_id IN (
    SELECT patient_id 
    FROM temp_earliest_start_date 
    WHERE earliest_start_date <= '{{ end_date }}'
  )
```

**Interpretation**:
- **Key Performance Indicator**: Primary treatment metric
- **Expected Trend**: Generally increasing (population growth)
- **Seasonality**: May fluctuate with adherence challenges (holidays, stock-outs)
- **Target**: Should be >80% of cumulative registered (retention goal)

**Data Quality Checks**:
- Compare against dispensary records (should have ARV dispensations)
- Verify against patient encounters (should have recent clinic visits)
- Check for gaps in prescription continuity

---

### 3. Defaulted (`defaulted`)

**Definition**: Number of unique patients classified as having "Defaulted" - meaning they are more than 2 months overdue after their expected ARV run-out date.

**Eligibility Criteria**:
- Patient has a valid ART start date
- Most recent patient state = "Defaulted"
- Computed as: Last dispensing date + days dispensed + 60 days < reporting date

**Calculation Method**:
- Queries `temp_patient_outcomes` table
- Filters for `moh_cum_outcome = 'Defaulted'`
- Counts distinct patient_id values

**SQL Logic**:
```sql
SELECT DISTINCT patient_id
FROM temp_patient_outcomes
WHERE moh_cum_outcome = 'Defaulted'
  AND patient_id IN (
    SELECT patient_id 
    FROM temp_earliest_start_date 
    WHERE earliest_start_date <= '{{ end_date }}'
  )
```

**Calculation of Default Status**:
```
Expected ARV Run-out Date = Last Dispensing Date + Days Dispensed
Default Status = Expected Run-out Date + 60 days < Reporting End Date
```

**Interpretation**:
- **Critical Indicator**: Identifies patients at risk
- **Default Rate**: (Defaulted / Alive & On ART) × 100
- **Expected Range**: <5% with good adherence programs
- **Trend**: Should generally decrease with intervention programs

**Related Outcomes**:
- Patients in state "Treatment stopped" - not included
- Patients in state "Patient died" - not included
- Patients in state "Patient transferred out" - not included

---

## Data Retrieval Methods

### Method 1: API REST Endpoint

**Endpoint**:
```
GET /api/v1/programs/:program_id/reports/cohort_disaggregated?name=Q1+2025
```

**Parameters**:
- `program_id`: 1 (for HIV PROGRAM)
- `name`: Quarter and year (e.g., "Q1 2025", "Q2 2025")
- `start_date`: Optional override (YYYY-MM-DD)
- `end_date`: Optional override (YYYY-MM-DD)
- `regenerate`: Set to "true" to rebuild cached data

**Response Format**:
```json
{
  "cum_total_registered": 12500,
  "total_alive_and_on_art": 9800,
  "defaulted": 450,
  "... other indicators ...": "..."
}
```

**Example Request**:
```bash
curl -X GET "http://localhost:3000/api/v1/programs/1/reports/cohort_disaggregated?name=Q1%202025"
```

### Method 2: Direct Database Query (MySQL)

**Connection Details**:
- Database: openmrs (or configured HIV database)
- Tables: patient, patient_program, patient_state, encounter, obs

**Sample Query - Cumulative Registered**:
```sql
SELECT COUNT(DISTINCT pp.patient_id) as cum_total_registered
FROM patient_program pp
INNER JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND ps.voided = 0
  AND ps.state = 7  -- ON ART state
  AND DATE(pp.date_enrolled) <= '2025-12-31'
GROUP BY pp.program_id;
```

**Sample Query - Alive and On ART**:
```sql
SELECT COUNT(DISTINCT pp.patient_id) as total_alive_and_on_art
FROM patient_program pp
INNER JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND ps.voided = 0
  AND ps.state = 7
  AND DATE(pp.date_enrolled) <= '2025-12-31'
  AND ps.start_date = (
    SELECT MAX(start_date)
    FROM patient_state
    WHERE patient_program_id = pp.patient_program_id
      AND voided = 0
  )
GROUP BY pp.program_id;
```

### Method 3: Ruby Console

```ruby
# Access via Rails console: rails c

# Initialize report service for HIV program
program = Program.find_by(name: 'HIV PROGRAM')
report_service = ReportService.new(program_id: program.id)

# For Q1 2025 (Jan 1 - Mar 31, 2025)
q1_2025 = report_service.cohort_disaggregated(
  quarter: "Q1 2025",
  age_group: "All",
  start_date: Date.new(2025, 1, 1),
  end_date: Date.new(2025, 3, 31),
  rebuild: false,
  init: false
)

puts "Cumulative Ever Registered: #{q1_2025.cum_total_registered.count}"
puts "Total Alive and On ART: #{q1_2025.total_alive_and_on_art.count}"
puts "Defaulted: #{q1_2025.defaulted.count}"
```

---

## Analysis Framework

### Quarterly Breakdown (2025)

| Quarter | Period | Cum Registered | Alive & On ART | Defaulted | Default Rate | Retention % |
|---------|--------|----------------|----|-----------|--------------|------------|
| Q1 2025 | Jan-Mar | [DATA] | [DATA] | [DATA] | [%] | [%] |
| Q2 2025 | Apr-Jun | [DATA] | [DATA] | [DATA] | [%] | [%] |
| Q3 2025 | Jul-Sep | [DATA] | [DATA] | [DATA] | [%] | [%] |
| Q4 2025 | Oct-Dec | [DATA] | [DATA] | [DATA] | [%] | [%] |

### Calculated Metrics

**1. Retention Rate**:
```
Retention % = (Total Alive & On ART / Cumulative Ever Registered) × 100
Expected: ≥90% in well-functioning programs
```

**2. Default Rate**:
```
Default % = (Defaulted / Total Alive & On ART) × 100
Expected: <5% with good adherence support
Target: <3% with excellent programs
```

**3. Cumulative Attrition**:
```
Attrition = Cumulative Ever Registered - Total Alive & On ART
(Includes: Defaulted + Deceased + Stopped + Transferred Out + Unknown)
```

**4. Quarter-on-Quarter Growth**:
```
QoQ Growth % = ((Current Qtr - Previous Qtr) / Previous Qtr) × 100
```

---

## Key File References

### Core Calculation Files
1. **[app/services/art_service/reports/cohort_builder.rb](../app/services/art_service/reports/cohort_builder.rb#L2238)**
   - Method `total_registered(start_date, end_date)` - Line 2238+
   - Method `get_outcome(outcome_name)` - Filters outcomes
   - Performance-optimized SQL queries

2. **[app/services/art_service/reports/cohort_struct.rb](../app/services/art_service/reports/cohort_struct.rb)**
   - Field definitions: `cum_total_registered`, `total_alive_and_on_art`, `defaulted`
   - Human-readable field descriptions

3. **[app/controllers/api/v1/program_reports_controller.rb](../app/controllers/api/v1/program_reports_controller.rb)**
   - Line 8: Parameter parsing for quarters
   - Line 26: `cohort_progress` endpoint for real-time progress

### Support Files
- **Outcome Classification**: [app/services/art_service/reports/cohort/outcomes.rb](../app/services/art_service/reports/cohort/outcomes.rb)
- **Temporary Table Management**: Lines in cohort_builder.rb
- **Database Schema**: OpenMRS patient, patient_program, patient_state tables

---

## Interpretation Guidelines

### Healthy ART Program Indicators

**Q1 2025 Targets**:
- Cumulative Ever Registered: Baseline (all-time total)
- Alive & On ART: ≥90% of cumulative registered
- Defaulted: <5% of those on ART
- Default Rate: <3%

### Red Flags

1. **Decreasing "Alive & On ART"**: 
   - Possible causes: Data errors, stock-outs, program disruption
   - Action: Verify dispensary records and patient encounters

2. **Increasing Default Rate Rapidly**:
   - Possible causes: Loss to follow-up, adherence challenges
   - Action: Activate defaulter tracing programs

3. **Cum Registered Decrease**:
   - **Critical Error**: Should never happen
   - Action: Audit data entry and voiding practices

4. **Retention <85%**:
   - Below international targets (PEPFAR, UNAIDS)
   - Action: Implement intensive adherence support

---

## Technical Performance Notes

### Query Optimization
- Uses temporary indexed tables for 50-100x performance improvement
- Parallel threading for independent indicator calculations
- Covering indexes on patient_state and obs tables

### Data Freshness
- Report generation can take 5-20 minutes for large facilities (50K+ patients)
- Cached results available immediately after initial generation
- Can force regeneration with `regenerate=true` parameter

### Scalability
- Tested on databases with 500K+ patient records
- Memory-efficient temporary table strategy
- Connection pooling for concurrent requests

---

## How to Use This Analysis

1. **Retrieve Data**: Use Method 1, 2, or 3 above to fetch quarterly data
2. **Populate Table**: Fill in the "Quarterly Breakdown" table with actual numbers
3. **Calculate Metrics**: Use formulas in "Calculated Metrics" section
4. **Compare Trends**: Look for quarter-to-quarter changes
5. **Benchmark**: Compare your retention/default rates against targets
6. **Investigate Anomalies**: Flag any metrics outside expected ranges

---

## Contact & Further Analysis

For detailed drill-downs by:
- **Age group**: HIV CLINIC CONSULTATION encounters with age calculations
- **Gender**: Filtering by person.gender field
- **Location**: By facility_id in patient_program
- **Regimen**: By drug_order and ARV drug classifications

See corresponding methods in [cohort_builder.rb](../app/services/art_service/reports/cohort_builder.rb)

**Last Updated**: 2026-08-10  
**Database Schema**: OpenMRS 2.x  
**API Version**: v1
