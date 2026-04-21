#!/bin/bash
# =============================================================================
# invoke-and-query.sh
#
# What this script does:
#   1. Invokes the Lambda function several times to generate log volume.
#   2. Waits a few seconds for CloudWatch to ingest the logs.
#   3. Runs three Log Insights queries to analyse the results.
#
# Requirements:
#   - AWS CLI installed and configured (aws configure)
#   - jq installed (brew install jq / apt install jq)
#   - Terraform already applied (the Lambda and log group must exist)
#
# Usage:
#   chmod +x invoke-and-query.sh
#   ./invoke-and-query.sh
# =============================================================================

set -euo pipefail  # Exit on error, treat unset variables as errors

# ---------------------------------------------------------------------------
# Configuration — edit these if you changed the defaults in variables.tf
# ---------------------------------------------------------------------------
FUNCTION_NAME="lab03-log-insights"
REGION="eu-west-3"
LOG_GROUP="/aws/lambda/${FUNCTION_NAME}"
INVOCATIONS=15       # Number of Lambda calls — more = richer data in Log Insights
WAIT_SECONDS=10      # CloudWatch ingestion is near-real-time but not instant

# Time window for Log Insights queries (last 30 minutes)
START_TIME=$(date -u -d "30 minutes ago" +%s 2>/dev/null || date -u -v-30M +%s)
END_TIME=$(date -u +%s)

# ---------------------------------------------------------------------------
# Helper: print a section header so the output is easy to scan
# ---------------------------------------------------------------------------
header() {
  echo ""
  echo "============================================================"
  echo "  $1"
  echo "============================================================"
}

# ---------------------------------------------------------------------------
# Step 1 — Invoke the Lambda multiple times
# ---------------------------------------------------------------------------
header "Invoking Lambda ${INVOCATIONS} times"

for i in $(seq 1 "$INVOCATIONS"); do
  # --payload '{}' sends an empty JSON object as the event (our handler ignores it)
  # /tmp/lambda-response.json captures the function's return value (we discard it)
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload '{}' \
    ./lambda-response.json \
    --output json > /dev/null   # suppress the CLI status output

  echo "  Invocation ${i}/${INVOCATIONS} done"
done

echo ""
echo "Waiting ${WAIT_SECONDS}s for CloudWatch to ingest the logs..."
sleep "$WAIT_SECONDS"

# ---------------------------------------------------------------------------
# Helper: run a Log Insights query and wait for results
#
# Log Insights queries are asynchronous:
#   1. start-query  → returns a queryId
#   2. get-query-results → poll until status is "Complete"
# ---------------------------------------------------------------------------
run_query() {
  local label="$1"   # Human-readable name for this query
  local query="$2"   # The Log Insights query string

  header "Query: ${label}"
  echo "  Log group : ${LOG_GROUP}"
  echo "  Query     : ${query}"
  echo ""

  # Start the query and grab its ID
  QUERY_ID=$(MSYS_NO_PATHCONV=1 aws logs start-query \
    --log-group-name "$LOG_GROUP" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --query-string "$query" \
    --region "$REGION" \
    --output json | jq -r '.queryId')

  # Poll until complete (usually finishes in 1-3 seconds)
  while true; do
    RESULT=$(aws logs get-query-results \
      --query-id "$QUERY_ID" \
      --region "$REGION" \
      --output json)

    STATUS=$(echo "$RESULT" | jq -r '.status')

    if [[ "$STATUS" == "Complete" ]]; then
      break
    fi

    echo "  Status: ${STATUS} — waiting..."
    sleep 2
  done

  # Print each result row as a clean key=value line
  echo "$RESULT" | jq -r '
    .results[] |
    map("\(.field) = \(.value)") |
    join("  |  ")
  '
}

# ---------------------------------------------------------------------------
# Step 2 — Run the three Log Insights queries
# ---------------------------------------------------------------------------

# Query 1: Count events by log level
# Useful to see the distribution of INFO / WARNING / ERROR at a glance.
run_query \
  "Count by log level" \
  "fields level | stats count() as total by level | sort total desc"

# Query 2: Show only ERROR events
# Useful to triage incidents — lists each error with its request_id and error_code.
run_query \
  "ERROR events only" \
  "fields request_id, message, error_code, duration_ms | filter level = \"ERROR\" | sort @timestamp desc | limit 10"

# Query 3: Average duration per log level
# Useful to detect performance regressions — are errors slower than successes?
run_query \
  "Average duration per level" \
  "fields level, duration_ms | stats avg(duration_ms) as avg_duration_ms by level | sort avg_duration_ms desc"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
header "All done"
echo "  You can also run these queries in the AWS Console:"
echo "  CloudWatch → Log Insights → select log group: ${LOG_GROUP}"
echo ""
echo "  See queries.md for the full list of queries with explanations."
