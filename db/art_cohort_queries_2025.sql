-- ART Cohort Report Analysis Query Suite
-- Purpose: Direct database queries for ART cohort indicators (2025 Q1 onwards)
-- Database: OpenMRS
-- Usage: Run queries in MySQL client against openmrs database

-- ============================================================================
-- SETUP: Create temporary analysis table for 2025 quarters
-- ============================================================================

CREATE TEMPORARY TABLE IF NOT EXISTS q1_2025_art_patients AS
SELECT DISTINCT pp.patient_id, pp.date_enrolled, pp.date_completed, 
       pp.program_id, ps.state, ps.start_date, ps.end_date, ps.voided,
       p.gender, p.birthdate, p.death_date
FROM patient_program pp
LEFT JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id
LEFT JOIN person p ON pp.patient_id = p.person_id
WHERE pp.program_id = 1  -- HIV PROGRAM
  AND pp.voided = 0
  AND pp.date_enrolled <= '2025-12-31';

-- ============================================================================
-- INDICATOR 1: CUMULATIVE EVER REGISTERED
-- Definition: All unique patients ever registered in HIV program through end of quarter
-- ============================================================================

-- Q1 2025 (Jan 1 - Mar 31, 2025)
SELECT 
  'Q1 2025' AS quarter,
  '2025-01-01' AS start_date,
  '2025-03-31' AS end_date,
  COUNT(DISTINCT pp.patient_id) AS cumulative_ever_registered,
  NOW() AS generated_at
FROM patient_program pp
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-03-31'
INTO OUTFILE '/tmp/q1_2025_cum_registered.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';

-- Q2 2025 (Apr 1 - Jun 30, 2025)
SELECT 
  'Q2 2025' AS quarter,
  '2025-04-01' AS start_date,
  '2025-06-30' AS end_date,
  COUNT(DISTINCT pp.patient_id) AS cumulative_ever_registered,
  NOW() AS generated_at
FROM patient_program pp
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-06-30';

-- Q3 2025 (Jul 1 - Sep 30, 2025)
SELECT 
  'Q3 2025' AS quarter,
  '2025-07-01' AS start_date,
  '2025-09-30' AS end_date,
  COUNT(DISTINCT pp.patient_id) AS cumulative_ever_registered,
  NOW() AS generated_at
FROM patient_program pp
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-09-30';

-- Q4 2025 (Oct 1 - Dec 31, 2025)
SELECT 
  'Q4 2025' AS quarter,
  '2025-10-01' AS start_date,
  '2025-12-31' AS end_date,
  COUNT(DISTINCT pp.patient_id) AS cumulative_ever_registered,
  NOW() AS generated_at
FROM patient_program pp
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-12-31';

-- ============================================================================
-- INDICATOR 2: TOTAL ALIVE AND ON ART
-- Definition: Current patients actively on antiretroviral treatment at quarter end
-- Criteria:
--   - Most recent state = ON TREATMENT (state_id = 7)
--   - Enrollment before or on quarter end date
--   - No recorded death date
-- ============================================================================

-- Helper: Get most recent patient states
CREATE TEMPORARY TABLE IF NOT EXISTS latest_patient_states AS
SELECT 
  patient_program_id,
  patient_id,
  state,
  start_date,
  ROW_NUMBER() OVER (PARTITION BY patient_program_id ORDER BY start_date DESC, patient_state_id DESC) AS rn
FROM patient_state
WHERE voided = 0;

-- Q1 2025 - Alive and On ART
SELECT 
  'Q1 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_alive_on_art,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_count,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_count,
  MIN(DATE(pp.date_enrolled)) AS program_start,
  MAX(DATE(pp.date_enrolled)) AS last_enrollment
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-03-31'
  AND lps.rn = 1
  AND lps.state = 7  -- ON ART
  AND p.death_date IS NULL
  AND pp.date_completed IS NULL;

-- Q2 2025 - Alive and On ART
SELECT 
  'Q2 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_alive_on_art,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_count,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_count,
  MIN(DATE(pp.date_enrolled)) AS program_start,
  MAX(DATE(pp.date_enrolled)) AS last_enrollment
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-06-30'
  AND lps.rn = 1
  AND lps.state = 7
  AND p.death_date IS NULL
  AND pp.date_completed IS NULL;

-- Q3 2025 - Alive and On ART
SELECT 
  'Q3 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_alive_on_art,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_count,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_count,
  MIN(DATE(pp.date_enrolled)) AS program_start,
  MAX(DATE(pp.date_enrolled)) AS last_enrollment
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-09-30'
  AND lps.rn = 1
  AND lps.state = 7
  AND p.death_date IS NULL
  AND pp.date_completed IS NULL;

-- Q4 2025 - Alive and On ART
SELECT 
  'Q4 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_alive_on_art,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_count,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_count,
  MIN(DATE(pp.date_enrolled)) AS program_start,
  MAX(DATE(pp.date_enrolled)) AS last_enrollment
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-12-31'
  AND lps.rn = 1
  AND lps.state = 7
  AND p.death_date IS NULL
  AND pp.date_completed IS NULL;

-- ============================================================================
-- INDICATOR 3: DEFAULTED PATIENTS
-- Definition: Patients more than 60 days late on ARV refill
-- Calculation: Last_dispensing_date + days_dispensed + 60 days < quarter_end_date
-- ============================================================================

-- Helper: Get last ARV dispensing per patient
CREATE TEMPORARY TABLE IF NOT EXISTS last_arv_dispensing AS
SELECT 
  e.patient_id,
  MAX(e.encounter_datetime) AS last_dispensing_date,
  o.value_numeric AS days_dispensed,
  e.encounter_id
FROM encounter e
INNER JOIN obs o ON e.encounter_id = o.encounter_id
INNER JOIN concept_name cn ON o.concept_id = cn.concept_id
WHERE e.encounter_type = 19  -- DISPENSING encounter
  AND cn.name = 'Amount dispensed'
  AND e.voided = 0
  AND o.voided = 0
GROUP BY e.patient_id;

-- Q1 2025 - Defaulted
SELECT 
  'Q1 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_defaulted
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
INNER JOIN last_arv_dispensing lad ON pp.patient_id = lad.patient_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-03-31'
  AND lps.rn = 1
  AND (
    DATE_ADD(
      DATE_ADD(lad.last_dispensing_date, INTERVAL COALESCE(lad.days_dispensed, 30) DAY),
      INTERVAL 60 DAY
    ) < '2025-03-31'
  )
  AND p.death_date IS NULL;

-- Q2 2025 - Defaulted
SELECT 
  'Q2 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_defaulted
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
INNER JOIN last_arv_dispensing lad ON pp.patient_id = lad.patient_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-06-30'
  AND lps.rn = 1
  AND (
    DATE_ADD(
      DATE_ADD(lad.last_dispensing_date, INTERVAL COALESCE(lad.days_dispensed, 30) DAY),
      INTERVAL 60 DAY
    ) < '2025-06-30'
  )
  AND p.death_date IS NULL;

-- Q3 2025 - Defaulted
SELECT 
  'Q3 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_defaulted
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
INNER JOIN last_arv_dispensing lad ON pp.patient_id = lad.patient_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-09-30'
  AND lps.rn = 1
  AND (
    DATE_ADD(
      DATE_ADD(lad.last_dispensing_date, INTERVAL COALESCE(lad.days_dispensed, 30) DAY),
      INTERVAL 60 DAY
    ) < '2025-09-30'
  )
  AND p.death_date IS NULL;

-- Q4 2025 - Defaulted
SELECT 
  'Q4 2025' AS quarter,
  COUNT(DISTINCT pp.patient_id) AS total_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'F' THEN pp.patient_id END) AS female_defaulted,
  COUNT(DISTINCT CASE WHEN LEFT(p.gender, 1) = 'M' THEN pp.patient_id END) AS male_defaulted
FROM patient_program pp
INNER JOIN person p ON pp.patient_id = p.person_id
INNER JOIN latest_patient_states lps ON pp.patient_program_id = lps.patient_program_id
INNER JOIN last_arv_dispensing lad ON pp.patient_id = lad.patient_id
WHERE pp.program_id = 1
  AND pp.voided = 0
  AND DATE(pp.date_enrolled) <= '2025-12-31'
  AND lps.rn = 1
  AND (
    DATE_ADD(
      DATE_ADD(lad.last_dispensing_date, INTERVAL COALESCE(lad.days_dispensed, 30) DAY),
      INTERVAL 60 DAY
    ) < '2025-12-31'
  )
  AND p.death_date IS NULL;

-- ============================================================================
-- COMBINED ANALYSIS: All three indicators in one result set
-- ============================================================================

SELECT 
  'Q1 2025' AS quarter,
  (SELECT COUNT(DISTINCT patient_id) FROM patient_program 
   WHERE program_id = 1 AND voided = 0 AND DATE(date_enrolled) <= '2025-03-31') AS cumulative_registered,
  (SELECT COUNT(DISTINCT pp.patient_id) FROM patient_program pp
   INNER JOIN person p ON pp.patient_id = p.person_id
   WHERE pp.program_id = 1 AND pp.voided = 0 AND DATE(pp.date_enrolled) <= '2025-03-31'
   AND p.death_date IS NULL) AS active_patients,
  0 AS total_alive_on_art,  -- To be calculated
  0 AS defaulted  -- To be calculated
UNION ALL
SELECT 'Q2 2025', NULL, NULL, NULL, NULL
UNION ALL
SELECT 'Q3 2025', NULL, NULL, NULL, NULL
UNION ALL
SELECT 'Q4 2025', NULL, NULL, NULL, NULL;

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Drop temporary tables when done
-- DROP TEMPORARY TABLE q1_2025_art_patients;
-- DROP TEMPORARY TABLE latest_patient_states;
-- DROP TEMPORARY TABLE last_arv_dispensing;
