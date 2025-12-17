#!/bin/bash

# GitHub Repository Contribution Stats
# Usage: ./github_stats.sh owner/repo

if [ -z "$1" ]; then
  echo "Usage: $0 owner/repo"
  echo "Example: $0 Enterprise-CMCS/macpro-mdct-qmr"
  exit 1
fi

REPO=$1
START_DATE="2025-01-01"

echo "Repository: $REPO"
echo "Date Range: Since January 1, 2025"
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
