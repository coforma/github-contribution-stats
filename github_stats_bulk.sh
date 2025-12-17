#!/bin/bash

# GitHub Repository Contribution Stats (Bulk)
# Usage: ./github_stats_bulk.sh repos.txt

if [ -z "$1" ]; then
  echo "Usage: $0 <repos-file>"
  echo "Example: $0 repos.txt"
  echo ""
  echo "File format: one repo per line (owner/repo)"
  exit 1
fi

REPOS_FILE=$1
START_DATE="2025-01-01"

if [ ! -f "$REPOS_FILE" ]; then
  echo "Error: File '$REPOS_FILE' not found"
  exit 1
fi

echo "Analyzing repositories since January 1, 2025"
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
