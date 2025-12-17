#!/bin/bash

# GitHub Repository Contribution Stats
# Usage: ./github_stats.sh owner/repo [since-date]

if [ -z "$1" ]; then
  echo "Usage: $0 owner/repo [since-date]"
  echo "Example: $0 coforma/github-contribution-stats"
  echo "Example: $0 coforma/github-contribution-stats 2025-01-01"
  echo "If no date is provided, defaults to January 1st of the current year"
  exit 1
fi

REPO=$1

# Use provided date or default to January 1st of current year
if [ -n "$2" ]; then
  START_DATE="$2"
else
  CURRENT_YEAR=$(date +%Y)
  START_DATE="$CURRENT_YEAR-01-01"
fi

echo "Repository: $REPO"
echo "Date Range: Since $START_DATE"
echo "============================================"
echo ""

echo "=== Commits (all branches) ==="
COMMITS=$(gh api "search/commits?q=repo:$REPO+committer-date:>=$START_DATE" --jq '.total_count')
echo "$COMMITS"

echo ""
echo "=== Pull Requests ==="
PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+created:>=$START_DATE" --jq '.total_count')
echo "$PRS"

echo ""
echo "============================================"
TOTAL=$((COMMITS + PRS))
echo "Total Contributions: $TOTAL"
