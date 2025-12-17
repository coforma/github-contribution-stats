#!/bin/bash

# GitHub Repository Contribution Stats (Bulk)
# Usage: ./github_stats_bulk.sh repos.txt [since-date]

if [ -z "$1" ]; then
  echo "Usage: $0 <repos-file> [since-date]"
  echo "Example: $0 repos.txt"
  echo "Example: $0 repos.txt 2025-01-01"
  echo ""
  echo "File format: one repo per line (owner/repo)"
  echo "If no date is provided, defaults to January 1st of the current year"
  exit 1
fi

REPOS_FILE=$1

# Use provided date or default to January 1st of current year
if [ -n "$2" ]; then
  START_DATE="$2"
else
  CURRENT_YEAR=$(date +%Y)
  START_DATE="$CURRENT_YEAR-01-01"
fi

if [ ! -f "$REPOS_FILE" ]; then
  echo "Error: File '$REPOS_FILE' not found"
  exit 1
fi

echo "Analyzing repositories since $START_DATE"
echo "============================================"
echo ""

TOTAL_COMMITS=0
TOTAL_PRS=0

while IFS= read -r REPO || [ -n "$REPO" ]; do
  # Skip empty lines and comments
  [[ -z "$REPO" || "$REPO" =~ ^[[:space:]]*# ]] && continue
  
  echo "Processing: $REPO"
  
  COMMITS=$(gh api "search/commits?q=repo:$REPO+committer-date:>=$START_DATE" --jq '.total_count' 2>/dev/null)
  PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+created:>=$START_DATE" --jq '.total_count' 2>/dev/null)
  
  if [ -z "$COMMITS" ]; then COMMITS=0; fi
  if [ -z "$PRS" ]; then PRS=0; fi
  
  REPO_TOTAL=$((COMMITS + PRS))
  
  echo "  Commits: $COMMITS"
  echo "  Pull Requests: $PRS"
  echo "  Subtotal: $REPO_TOTAL"
  echo ""
  
  TOTAL_COMMITS=$((TOTAL_COMMITS + COMMITS))
  TOTAL_PRS=$((TOTAL_PRS + PRS))
done < "$REPOS_FILE"

GRAND_TOTAL=$((TOTAL_COMMITS + TOTAL_PRS))

echo "============================================"
echo "SUMMARY"
echo "============================================"
echo "Total Commits: $TOTAL_COMMITS"
echo "Total Pull Requests: $TOTAL_PRS"
echo "Grand Total: $GRAND_TOTAL"
