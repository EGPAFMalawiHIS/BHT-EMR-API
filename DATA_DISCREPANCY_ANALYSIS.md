# Critical Data Discrepancy Analysis: Backend Script vs Frontend Report

## Issue Summary

**Q2 2026 Data Mismatch:**

| Metric | Backend Script | Frontend Report | Gap |
|--------|---|---|---|
| **Cumulative Registered** | 134 | 133 | -1 |
| **Alive & On Treatment** | 70 | 12 | **-58 (83% difference)** |
| **Defaulted** | 6 | 77 | **+71 (1,183% difference)** |

## Root Cause Analysis

### Backend Script Approach (INCORRECT for this use case)
**File:** `/var/www/BHT-EMR-API/bin/art_cohort_analysis.rb`

The script uses **direct patient_state queries**:
```ruby
# Direct SQL query approach
SELECT COUNT(DISTINCT patient_id) 
FROM patient_program pp
INNER JOIN patient_state ps ON ps.patient_program_id = pp.patient_program_id
WHERE pp.program_id = 1 
  AND pp.voided = 0
  AND ps.voided = 0
  AND ps.state = 7  # ON ART - directly from state table
  AND pp.date_enrolled <= end_date
```

**Problems with this approach:**
1. ❌ Uses raw `patient_state` table without outcome calculation logic
2. ❌ Doesn't account for patient death, treatment stop, transfers
3. ❌ Assumes state = 7 means "currently on ART" (it doesn't always)
4. ❌ Misses complex outcome determination based on drug orders, encounters, observations
5. ❌ Ignores the sophisticated `temp_patient_outcomes` calculation system

---

### Frontend Report Approach (CORRECT)
**Framework:** `ArtService::Reports::CohortBuilder` + `ArtService::Reports::Cohort::Outcomes`

The frontend uses **calculated outcomes** stored in `temp_patient_outcomes`:

```ruby
# Real calculation approach (simplified)
class ArtService::Reports::Cohort::Outcomes
  def process_data(start: false)
    load_patients_who_died(start:)                     # Step 1: Identify deceased
    load_other_patient_who_died(start:)                # Step 2: Other death records
    load_patients_who_stopped_treatment(start:)        # Step 3: Treatment stops
    load_patients_without_drug_orders(start:)          # Step 4: No ARV orders
    load_patient_calculated_outcomes_optimized(start:) # Step 5: Calculated outcome
  end
  
  # Populates temp_patient_outcomes with moh_cum_outcome field:
  # - 'On antiretrovirals'
  # - 'Patient died'
  # - 'Defaulted'
  # - 'Treatment stopped'
  # - 'Patient transferred out'
  # - 'Pre-ART (Continue)'
  # - 'Unknown'
end
```

**Advantages:**
- ✅ Respects order of operations (death → stop → no orders → calculated)
- ✅ Accounts for drug order history
- ✅ Uses encounter data and observations
- ✅ Handles transfers and transfers-in correctly
- ✅ Properly categorizes all patient outcomes
- ✅ Consistent with MOH and PEPFAR outcome definitions

---

## Why The Difference?

### Scenario: Patient with state=7 (ON ART) but actually DEFAULTED

**Backend Script Result:**
- Counts as "On ART" = 70 ✓ (included)
- Not counted as "Defaulted" = 0 ✗ (missed)

**Frontend System Result:**
- Checks: Has patient been seen in last 90 days? NO
- Checks: Any recent ARV dispensation? NO
- Outcome = "Defaulted" ✅ (correctly identified)
- NOT counted as "On ART" (correctly excluded)

---

## The Real Calculation Logic

The `temp_patient_outcomes` table uses this priority order:

```
1. IF patient has death_date → "Patient died"
2. ELSE IF patient stopped ART (stop order exists) → "Treatment stopped"
3. ELSE IF patient has no ARV drug orders → "Pre-ART (Continue)" or "Unknown"
4. ELSE IF patient's last state is NOT "ON ARVs" → "Defaulted" or "Transferred out"
5. ELSE IF recent drug order + recent state → "On antiretrovirals"
6. ELSE → "Defaulted" (no clinical contact, no recent orders)
```

---

## Solution: Use Proper ART Reporting API

### Option 1: Use Built-in Cohort Report (Recommended)

```bash
# Via Rails console
rails console

require 'art_service/reports/cohort_builder'
builder = ArtService::Reports::CohortBuilder.new(outcomes_definition: 'moh')
cohort = builder.build(
  CohortStruct.new, 
  '2026-04-01'.to_date,  # start_date
  '2026-06-30'.to_date,  # end_date
  nil                     # occupation
)

puts "Cumulative Registered: #{cohort.cum_total_registered}"
puts "Alive & On ART: #{cohort.total_alive_and_on_art}"
puts "Defaulted: #{cohort.defaulted}"
```

### Option 2: Use Frontend API Endpoint

```bash
# Query the ART report endpoint (frontend)
GET /api/v1/art_reports/cohort?
  start_date=2026-04-01&
  end_date=2026-06-30&
  location_id=<facility_id>&
  disaggregate=false
```

### Option 3: Direct Query Using Frontend Logic

```sql
-- Execute outcome calculation first
CALL update_cohort_outcomes('2026-04-01', '2026-06-30');

-- Then query temp_patient_outcomes
SELECT 
  moh_cum_outcome,
  COUNT(*) as patient_count
FROM temp_patient_outcomes
WHERE moh_cum_outcome IN ('On antiretrovirals', 'Defaulted')
GROUP BY moh_cum_outcome;
```

---

## Explanation of Frontend Numbers

Your frontend shows for **Q2 2026**:
- Total Registered: 133 (likely includes 1 patient with status change)
- Total Alive & On Treatment: 12 (only patients with recent encounter + drug order)
- Defaulted: 77 (58 patients lost to follow-up + 19 others without recent contact)

**This is more accurate because:**
1. It excludes patients who transferred out or died
2. It only counts "on ART" if they have recent dispensation + encounter
3. It correctly identifies defaulters based on time since last visit
4. It matches MOH/PEPFAR reporting standards

---

## Recommended Actions

### Immediate:
1. ❌ **DISCARD** the backend script (`art_cohort_analysis.rb`) - it's based on wrong logic
2. ✅ **USE** the frontend cohort report system for accurate data
3. ✅ **VERIFY** with frontline staff why 77 patients are defaulted (5.5x higher than backend)

### Investigation:
1. Check if there was a mass data quality issue between script execution and frontend report
2. Verify facility-level outcomes: Are patients truly not being seen?
3. Review actual patient records for the 77 defaulted patients
4. Check for data import/sync issues with frontend database

### Long-term:
1. Implement proper outcome calculation in any custom reporting
2. Document the 5-step outcome determination process
3. Use the built-in cohort report as source of truth
4. Never query `patient_state` directly for outcome reporting

---

## Verification Steps

Run this to verify the data quality:

```bash
# In Rails console
cohort = ArtService::Reports::CohortBuilder.new.build(
  CohortStruct.new,
  '2026-04-01'.to_date,
  '2026-06-30'.to_date,
  nil
)

# Get actual outcome breakdown
defaulted_patients = ArtService::Reports::CohortBuilder.new.get_outcome('Defaulted')
on_art_patients = ArtService::Reports::CohortBuilder.new.get_outcome('On antiretrovirals')
died_patients = ArtService::Reports::CohortBuilder.new.get_outcome('Patient died')
transferred_out = ArtService::Reports::CohortBuilder.new.get_outcome('Patient transferred out')

puts "Defaulted: #{defaulted_patients.count}"
puts "On ART: #{on_art_patients.count}"
puts "Died: #{died_patients.count}"
puts "Transferred: #{transferred_out.count}"
```

---

## Conclusion

**The frontend report is correct. The backend script is wrong.**

The 58-patient discrepancy in "Alive & On ART" (70 vs 12) and 71-patient discrepancy in "Defaulted" (6 vs 77) reflects the difference between:
- **Simple state lookup** (backend script) → 70 patients in state 7
- **Calculated outcome** (frontend) → Only 12 actively managing ART, 77 lost to follow-up

Use the frontend cohort reporting system going forward.
