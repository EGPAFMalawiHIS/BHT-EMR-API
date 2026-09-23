#!/bin/bash

# ==============================================================================
# MOH Cohort Report Performance Testing Script
# ==============================================================================
# This script tests the end-to-end performance of generating a quarterly
# MOH cohort report by:
#   1. Authenticating with the API
#   2. Triggering the cohort report generation (queues background job)
#   3. Monitoring the database for job completion
#   4. Reporting total generation time and statistics
#
# The report generation runs asynchronously via a background job, so this
# script polls the database until the report is created.
# ==============================================================================

echo "========================================="
echo "MOH Cohort Report Performance Test"
echo "========================================="
echo ""
echo "Quarter: Q4 2025"
echo "Date Range: October 1, 2025 - December 31, 2025"
echo "Report Type: Cohort (with regeneration)"
echo ""

# API Configuration
API_BASE_URL="http://localhost:3001/api/v1"
LOGIN_ENDPOINT="/auth/login"
PROGRAM_ID="1"  # HIV Program
ENDPOINT="/programs/${PROGRAM_ID}/reports/cohort"

# Get credentials from user
read -p "Enter username: " USERNAME
read -sp "Enter password: " PASSWORD
echo ""
echo ""

# Authenticate and get API key
echo "Authenticating..."
LOGIN_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Client: EMASTERCARD" \
  -H "Client-Version: v2025.Q4.R6" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
  "${API_BASE_URL}${LOGIN_ENDPOINT}")

API_KEY=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
    echo "Authentication failed!"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

echo "Authentication successful!"
echo ""

# Parameters for Q4 2025
QUARTER_NAME="Q4%202025"
REGENERATE="true"

# Build the full URL
URL="${API_BASE_URL}${ENDPOINT}?name=${QUARTER_NAME}&regenerate=${REGENERATE}"

echo "Calling endpoint:"
echo "$URL"
echo ""
echo "========================================="
echo "Triggering report generation..."
echo "========================================="
echo ""

# Trigger the report generation
START_TIME=$(date +%s.%N)

TRIGGER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Authorization: $API_KEY" \
  -H "Client: EMASTERCARD" \
  -H "Client-Version: v2025.Q4.R6" \
  "$URL")

HTTP_STATUS=$(echo "$TRIGGER_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)

if [ "$HTTP_STATUS" = "204" ]; then
    echo "✓ Job successfully queued (HTTP 204)"
elif [ "$HTTP_STATUS" = "200" ]; then
    echo "✓ Report already exists or returned immediately (HTTP 200)"
else
    echo "✗ Failed to queue report (HTTP $HTTP_STATUS)"
    echo ""
    echo "Response:"
    echo "$TRIGGER_RESPONSE" | grep -v "HTTP_STATUS:"
    exit 1
fi
echo ""

QUEUE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "Job successfully queued at: $QUEUE_TIME"
echo ""
echo "Monitoring database for report completion..."
echo "========================================="
echo ""
echo "Polling every 3 seconds (max wait: 15 minutes)..."

POLL_COUNT=0
MAX_POLLS=300  # 15 minutes max wait time (300 * 3 seconds)

while [ $POLL_COUNT -lt $MAX_POLLS ]; do
    # Use Rails to check if report exists (more reliable than direct MySQL)
    REPORT_CHECK=$(rails runner "
      report = Report.where(name: 'Q4 2025', retired: false)
                     .where('date_created >= ?', Time.now - 20.minutes)
                     .order(date_created: :desc).first
      if report
        puts 'FOUND'
        puts report.id
        puts report.date_created.strftime('%Y-%m-%d %H:%M:%S')
        puts report.values.count
      else
        puts 'NOT_FOUND'
      end
    " 2>/dev/null)
    
    STATUS=$(echo "$REPORT_CHECK" | head -1)
    
    if [ "$STATUS" = "FOUND" ]; then
        END_TIME=$(date +%s.%N)
        
        REPORT_ID=$(echo "$REPORT_CHECK" | sed -n '2p')
        REPORT_CREATED=$(echo "$REPORT_CHECK" | sed -n '3p')
        VALUE_COUNT=$(echo "$REPORT_CHECK" | sed -n '4p')
        
        # Calculate elapsed time
        ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
        MINUTES=$(echo "$ELAPSED / 60" | bc)
        SECONDS=$(echo "$ELAPSED % 60" | bc)
        
        echo ""
        echo ""
        echo "========================================="
        echo "Report Generation Complete!"
        echo "========================================="
        echo ""
        echo "Queue Time:   $QUEUE_TIME"
        echo "Complete Time: $REPORT_CREATED"
        echo ""
        echo "Total Time: ${MINUTES} minutes and ${SECONDS} seconds (${ELAPSED}s total)"
        echo ""
        echo "Report Statistics:"
        echo "  - Report ID: $REPORT_ID"
        echo "  - Quarter: Q4 2025"
        echo "  - Date Range: 2025-10-01 to 2025-12-31"
        echo "  - Number of Values/Indicators: $VALUE_COUNT"
        echo ""
        echo "========================================="
        echo "Test completed successfully at: $(date)"
        echo "========================================="
        exit 0
    fi
    
    POLL_COUNT=$((POLL_COUNT + 1))
    printf "."
    sleep 3
done

echo ""
echo ""
echo "========================================="
echo "Timeout: Report generation took longer than 15 minutes"
echo "========================================="
echo ""
echo "The job may still be running. Check the database manually:"
echo "  rails runner \"puts Report.where(name: 'Q4 2025').order(date_created: :desc).first&.date_created\""
echo ""
exit 1
