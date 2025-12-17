#!/bin/bash

# GitHub Repository Contribution Stats
# Usage: ./github_stats.sh owner/repo [since-date] [--users users-file]

USERS_FILE=""

# Parse arguments
REPO=""
START_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --users)
      USERS_FILE="$2"
      shift 2
      ;;
    *)
      if [ -z "$REPO" ]; then
        REPO="$1"
      elif [ -z "$START_DATE" ]; then
        START_DATE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$REPO" ]; then
  echo "Usage: $0 owner/repo [since-date] [--users users-file]"
  echo "Example: $0 coforma/github-contribution-stats"
  echo "Example: $0 coforma/github-contribution-stats 2025-01-01"
  echo "Example: $0 coforma/github-contribution-stats 2025-01-01 --users users.txt"
  echo "If no date is provided, defaults to January 1st of the current year"
  exit 1
fi

# Use provided date or default to January 1st of current year
if [ -z "$START_DATE" ]; then
  CURRENT_YEAR=$(date +%Y)
  START_DATE="$CURRENT_YEAR-01-01"
fi

# Build user filter if users file is provided
USER_FILTER=""
if [ -n "$USERS_FILE" ]; then
  if [ ! -f "$USERS_FILE" ]; then
    echo "Error: Users file '$USERS_FILE' not found"
    exit 1
  fi
  
  while IFS= read -r USERNAME || [ -n "$USERNAME" ]; do
    # Skip empty lines and comments
    [[ -z "$USERNAME" || "$USERNAME" =~ ^[[:space:]]*# ]] && continue
    USER_FILTER="${USER_FILTER}+author:${USERNAME}"
  done < "$USERS_FILE"
fi

echo "Repository: $REPO"
echo "Date Range: Since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by users from: $USERS_FILE"
fi
echo "============================================"
echo ""

echo "=== Commits (all branches) ==="
COMMITS=$(gh api "search/commits?q=repo:$REPO+committer-date:>=$START_DATE$USER_FILTER" --jq '.total_count')
echo "$COMMITS"

echo ""
echo "=== Pull Requests ==="
PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+created:>=$START_DATE$USER_FILTER" --jq '.total_count')
echo "$PRS"

echo ""
echo "============================================"
TOTAL=$((COMMITS + PRS))
echo "Total Contributions: $TOTAL"
