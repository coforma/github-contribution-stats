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

# Load users into array if users file is provided
USERS=()
if [ -n "$USERS_FILE" ]; then
  if [ ! -f "$USERS_FILE" ]; then
    echo "Error: Users file '$USERS_FILE' not found"
    exit 1
  fi
  
  while IFS= read -r USERNAME || [ -n "$USERNAME" ]; do
    # Skip empty lines and comments
    [[ -z "$USERNAME" || "$USERNAME" =~ ^[[:space:]]*# ]] && continue
    USERS+=("$USERNAME")
  done < "$USERS_FILE"
  
  if [ ${#USERS[@]} -eq 0 ]; then
    echo "Error: No valid usernames found in '$USERS_FILE'"
    exit 1
  fi
fi

echo "Repository: $REPO"
echo "Date Range: Since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by ${#USERS[@]} users from: $USERS_FILE"
fi
echo "============================================"
echo ""

DELAY_SECONDS=2
MAX_RETRIES=3

echo "=== Commits (all branches) ==="

COMMITS=0

# If users are specified, query each user individually
if [ ${#USERS[@]} -gt 0 ]; then
  for USERNAME in "${USERS[@]}"; do
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      USER_COMMITS=$(gh api "search/commits?q=repo:$REPO+author:$USERNAME+committer-date:>=$START_DATE" --jq '.total_count' 2>&1)
      
      # Check for rate limit error
      if echo "$USER_COMMITS" | grep -q "rate limit\|API rate limit\|403"; then
        echo "⚠️  Rate limit hit, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      break
    done
    
    if [ -z "$USER_COMMITS" ] || ! [[ "$USER_COMMITS" =~ ^[0-9]+$ ]]; then USER_COMMITS=0; fi
    COMMITS=$((COMMITS + USER_COMMITS))
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all contributions
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    COMMITS=$(gh api "search/commits?q=repo:$REPO+committer-date:>=$START_DATE+-author:dependabot+-author:dependabot[bot]" --jq '.total_count' 2>&1)
    
    # Check for rate limit error
    if echo "$COMMITS" | grep -q "rate limit\|API rate limit\|403"; then
      echo "⚠️  Rate limit hit, waiting 60 seconds..."
      sleep 60
      RETRY_COUNT=$((RETRY_COUNT + 1))
      continue
    fi
    
    break
  done
  
  if [ -z "$COMMITS" ] || ! [[ "$COMMITS" =~ ^[0-9]+$ ]]; then COMMITS=0; fi
fi

echo "$COMMITS"

echo ""
echo "=== Pull Requests ==="

PRS=0

# If users are specified, query each user individually
if [ ${#USERS[@]} -gt 0 ]; then
  for USERNAME in "${USERS[@]}"; do
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      USER_PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+author:$USERNAME+created:>=$START_DATE" --jq '.total_count' 2>&1)
      
      # Check for rate limit error
      if echo "$USER_PRS" | grep -q "rate limit\|API rate limit\|403"; then
        echo "⚠️  Rate limit hit, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      break
    done
    
    if [ -z "$USER_PRS" ] || ! [[ "$USER_PRS" =~ ^[0-9]+$ ]]; then USER_PRS=0; fi
    PRS=$((PRS + USER_PRS))
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all contributions
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+created:>=$START_DATE+-author:dependabot+-author:dependabot[bot]" --jq '.total_count' 2>&1)
    
    # Check for rate limit error
    if echo "$PRS" | grep -q "rate limit\|API rate limit\|403"; then
      echo "⚠️  Rate limit hit, waiting 60 seconds..."
      sleep 60
      RETRY_COUNT=$((RETRY_COUNT + 1))
      continue
    fi
    
    break
  done
  
  if [ -z "$PRS" ] || ! [[ "$PRS" =~ ^[0-9]+$ ]]; then PRS=0; fi
fi

echo "$PRS"

echo ""
echo "============================================"
TOTAL=$((COMMITS + PRS))
echo "Total Contributions: $TOTAL"
