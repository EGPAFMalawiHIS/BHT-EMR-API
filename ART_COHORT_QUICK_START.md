# ART Cohort Report - Quick Start Guide

## Overview
This guide provides step-by-step instructions to retrieve and analyze ART cohort data for Q1 2025 onwards, focusing on three key indicators:
- **Cumulative Ever Registered**
- **Total Alive and On ART**
- **Defaulted**

---

## Quick Navigation

| Resource | Purpose | Located At |
|----------|---------|-----------|
| Full Analysis Doc | Comprehensive definitions & guidelines | `ART_COHORT_ANALYSIS_Q1_2025_ONWARDS.md` |
| Ruby Script | Automated data retrieval | `bin/art_cohort_report_2025.rb` |
| SQL Queries | Direct database queries | `db/art_cohort_queries_2025.sql` |
| This Guide | Quick setup instructions | This file |

---

## Option 1: Using the Ruby Script (Recommended)

### Prerequisites
- Rails environment configured
- Database connectivity verified
- Access to BHT-EMR-API repository

### Steps

**1. Navigate to the API directory**
```bash
cd /var/www/BHT-EMR-API
```

**2. Run the script**
```bash
rails runner bin/art_cohort_report_2025.rb
```

**3. Output Files Generated**
- `art_cohort_report_YYYYMMDD_HHMMSS.csv` - Excel-ready data
- `art_cohort_report_YYYYMMDD_HHMMSS.json` - Machine-readable format
- Console output - Summary statistics

**4. Expected Output**
```
============================================================
 ART COHORT ANALYSIS SUMMARY (2025)
============================================================

BASELINE (Q1 2025):
  • Total Cumulative Registered: 12,500
  • Alive & On ART: 11,200
  • Defaulted: 450

TRENDS ACROSS 2025:
  Q1 2025 → Q2 2025:
    - Cumulative Registered Growth: +350 patients
    - Alive & On ART Change: +280 patients
    - Defaulted Change: +25 patients
```

---

## Option 2: Using the API Endpoint

### Prerequisites
- API server running
- Postman, curl, or HTTP client available

### Steps

**1. Make HTTP Request**
```bash
curl -X GET "http://localhost:3000/api/v1/programs/1/reports/cohort_disaggregated?name=Q1%202025"
```

**2. Alternative with curl (formatted)**
```bash
curl -X GET \
  "http://localhost:3000/api/v1/programs/1/reports/cohort_disaggregated" \
  -H "Accept: application/json" \
  -d "name=Q1 2025" \
  | jq .
```

**3. For Multiple Quarters**
```bash
for quarter in "Q1 2025" "Q2 2025" "Q3 2025" "Q4 2025"; do
  echo "=== $quarter ==="
  curl -s -X GET \
    "http://localhost:3000/api/v1/programs/1/reports/cohort_disaggregated?name=${quarter// /%20}" \
    | jq '{cum_total_registered, total_alive_and_on_art, defaulted}'
done
```

---

## Option 3: Direct Database Queries

### Prerequisites
- MySQL client installed
- Database credentials available
- SSH access to database server (if remote)

### Steps

**1. Connect to Database**
```bash
mysql -u openmrs_user -p openmrs_password -h localhost openmrs
```

**2. Run Queries**
```sql
-- Copy and paste queries from db/art_cohort_queries_2025.sql
-- Start with INDICATOR 1 queries
```

**3. Save Results to CSV**
```sql
SELECT 'Q1 2025' AS quarter, COUNT(*) AS total
INTO OUTFILE '/tmp/art_cohort_q1_2025.csv'
FIELDS TERMINATED BY ','
FROM ...
```

**4. Export from Command Line**
```bash
mysql -u openmrs_user -p openmrs_password openmrs < db/art_cohort_queries_2025.sql > art_cohort_results.csv
```

---

## Option 4: Interactive Rails Console

### Prerequisites
- Rails environment configured

### Steps

**1. Open Rails Console**
```bash
cd /var/www/BHT-EMR-API
rails console
```

**2. Run Analysis**
```ruby
program = Program.find_by(name: 'HIV PROGRAM')
service = ReportService.new(program_id: program.id)

# Q1 2025
q1_report = service.cohort_disaggregated(
  quarter: "Q1 2025",
  age_group: "All",
  start_date: Date.new(2025, 1, 1),
  end_date: Date.new(2025, 3, 31),
  rebuild: false,
  init: false
)

puts "Cumulative Registered: #{q1_report.cum_total_registered.count}"
puts "Alive & On ART: #{q1_report.total_alive_and_on_art.count}"
puts "Defaulted: #{q1_report.defaulted.count}"
```

**3. Calculate Metrics Inline**
```ruby
cum = q1_report.cum_total_registered.count
on_art = q1_report.total_alive_and_on_art.count
defaulted = q1_report.defaulted.count

retention = (on_art.to_f / cum * 100).round(2)
default_rate = (defaulted.to_f / on_art * 100).round(2)

puts "Retention Rate: #{retention}%"
puts "Default Rate: #{default_rate}%"
```

---

## Data Interpretation Template

After retrieving data, fill in this template:

```markdown
# ART Cohort Analysis Report - 2025

## Q1 2025 (Jan 1 - Mar 31)
- **Cumulative Ever Registered**: _______________
- **Total Alive & On ART**: _______________
- **Defaulted**: _______________
- **Retention Rate (%)**: _______________
- **Default Rate (%)**: _______________

## Q2 2025 (Apr 1 - Jun 30)
- **Cumulative Ever Registered**: _______________
- **Total Alive & On ART**: _______________
- **Defaulted**: _______________
- **Retention Rate (%)**: _______________
- **Default Rate (%)**: _______________

## Q3 2025 (Jul 1 - Sep 30)
- **Cumulative Ever Registered**: _______________
- **Total Alive & On ART**: _______________
- **Defaulted**: _______________
- **Retention Rate (%)**: _______________
- **Default Rate (%)**: _______________

## Q4 2025 (Oct 1 - Dec 31)
- **Cumulative Ever Registered**: _______________
- **Total Alive & On ART**: _______________
- **Defaulted**: _______________
- **Retention Rate (%)**: _______________
- **Default Rate (%)**: _______________

## Analysis Notes
[Your interpretation and observations here]
```

---

## Troubleshooting

### Problem: "Report not found... Queueing one..."
**Solution**: Reports are generated asynchronously. Wait 5-20 minutes and try again, or use `regenerate=true`:
```bash
curl "http://localhost:3000/api/v1/programs/1/reports/cohort_disaggregated?name=Q1%202025&regenerate=true"
```

### Problem: "Connection timeout"
**Solution**: Database connection issue
- Verify MySQL is running: `sudo service mysql status`
- Check credentials in `config/database.yml`
- Verify database exists: `mysql -u root -p -e "SHOW DATABASES;"`

### Problem: "No data returned"
**Solutions**:
1. Verify patients exist: `SELECT COUNT(*) FROM patient_program WHERE program_id = 1;`
2. Check date format: Should be 'YYYY-MM-DD'
3. Verify program_id: HIV PROGRAM is usually program_id = 1
4. Check for voided records affecting the count

### Problem: Script returns 0 for all indicators
**Solution**: Likely temporary tables not initialized. Run with `rebuild=true`:
```bash
# In Rails console
service.cohort_disaggregated(..., rebuild: true, init: true)
```

---

## Performance Notes

| Method | Speed | Accuracy | Use Case |
|--------|-------|----------|----------|
| API (cached) | <1 second | High | Regular monitoring |
| API (regenerate) | 5-20 min | Highest | Audit/verification |
| Ruby script | 10-30 min | High | Batch analysis |
| SQL direct | 1-5 min | High | System admin |
| Rails console | Variable | High | Ad-hoc queries |

**Recommendation**: Use cached API for quick checks, Ruby script for comprehensive reports.

---

## Verification Checklist

Before finalizing your analysis, verify:

- [ ] Data covers full quarters (start and end dates correct)
- [ ] Cumulative registered never decreases quarter-to-quarter
- [ ] Total alive & on ART ≤ Cumulative registered
- [ ] Defaulted ≤ Total alive & on ART
- [ ] Retention rate ≥ 80% (healthy program)
- [ ] Default rate < 5% (acceptable), target <3%
- [ ] No negative numbers in any indicator
- [ ] Timestamps for each data retrieval recorded

---

## Next Steps

1. **Execute** your chosen retrieval method (Option 1-4 above)
2. **Record** results in the template provided
3. **Calculate** retention and default rates
4. **Compare** against benchmarks (see full analysis document)
5. **Investigate** any anomalies
6. **Document** findings and recommendations

---

## Additional Resources

- **Full Technical Guide**: [ART_COHORT_ANALYSIS_Q1_2025_ONWARDS.md](ART_COHORT_ANALYSIS_Q1_2025_ONWARDS.md)
- **Code References**:
  - Indicator logic: [cohort_builder.rb](app/services/art_service/reports/cohort_builder.rb)
  - Field definitions: [cohort_struct.rb](app/services/art_service/reports/cohort_struct.rb)
  - API endpoint: [program_reports_controller.rb](app/controllers/api/v1/program_reports_controller.rb)

- **OpenMRS Documentation**: https://openmrs.org/
- **PEPFAR Indicators**: Standard reporting metrics

---

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review the Full Analysis Document
3. Examine the code comments in implementation files
4. Contact database administrator if SQL queries fail

**Last Updated**: 2026-08-10
