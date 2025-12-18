#!/bin/bash

# GitHub Repository Contribution Stats (Bulk)
# Usage: ./github_stats_bulk.sh repos.txt [since-date] [--users users-file] [--org organization]

USERS_FILE=""
ORG=""

# Parse arguments
REPOS_FILE=""
START_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --users)
      USERS_FILE="$2"
      shift 2
      ;;
    --org)
      ORG="$2"
      shift 2
      ;;
    *)
      if [ -z "$REPOS_FILE" ]; then
        REPOS_FILE="$1"
      elif [ -z "$START_DATE" ]; then
        START_DATE="$1"
      fi
      shift
      ;;
  esac
done

# Validate arguments
if [ -z "$REPOS_FILE" ] && [ -z "$ORG" ]; then
  echo "Usage: $0 <repos-file> [since-date] [--users users-file]"
  echo "   or: $0 --org <organization> [since-date] [--users users-file]"
  echo ""
  echo "Examples:"
  echo "  $0 repos.txt"
  echo "  $0 repos.txt 2025-01-01"
  echo "  $0 repos.txt 2025-01-01 --users users.txt"
  echo "  $0 --org coforma"
  echo "  $0 --org coforma 2025-01-01 --users users.txt"
  echo ""
  echo "File format: one repo per line (owner/repo)"
  echo "If no date is provided, defaults to January 1st of the current year"
  exit 1
fi

if [ -n "$REPOS_FILE" ] && [ -n "$ORG" ]; then
  echo "Error: Cannot use both repos-file and --org flag"
  exit 1
fi

# Use provided date or default to January 1st of current year
if [ -z "$START_DATE" ]; then
  CURRENT_YEAR=$(date +%Y)
  START_DATE="$CURRENT_YEAR-01-01"
fi

# If using --org flag, fetch all repos from the organization
if [ -n "$ORG" ]; then
  echo "Fetching repositories from organization: $ORG"
  TEMP_REPOS_FILE=$(mktemp)
  gh repo list "$ORG" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' > "$TEMP_REPOS_FILE" 2>/dev/null
  
  if [ $? -ne 0 ] || [ ! -s "$TEMP_REPOS_FILE" ]; then
    echo "Error: Failed to fetch repositories from organization '$ORG'"
    rm -f "$TEMP_REPOS_FILE"
    exit 1
  fi
  
  REPOS_FILE="$TEMP_REPOS_FILE"
  REPO_COUNT=$(wc -l < "$TEMP_REPOS_FILE" | tr -d ' ')
  echo "Found $REPO_COUNT repositories"
  echo ""
fi

if [ ! -f "$REPOS_FILE" ]; then
  echo "Error: File '$REPOS_FILE' not found"
  exit 1
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

echo "Analyzing repositories since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by ${#USERS[@]} users from: $USERS_FILE"
fi
echo "============================================"
echo ""

TOTAL_COMMITS=0
TOTAL_PRS=0
REQUEST_COUNT=0

# Rate limit configuration
# GitHub Search API: 30 requests/min for authenticated users
# Add delay between requests to stay under limits
DELAY_SECONDS=2

while IFS= read -r REPO || [ -n "$REPO" ]; do
  # Skip empty lines and comments
  [[ -z "$REPO" || "$REPO" =~ ^[[:space:]]*# ]] && continue
  
  echo "Processing: $REPO"
  
  REPO_COMMITS=0
  REPO_PRS=0
  
  # If users are specified, query each user individually
  if [ ${#USERS[@]} -gt 0 ]; then
    for USERNAME in "${USERS[@]}"; do
      # Fetch commits for this user with retry logic
      RETRY_COUNT=0
      MAX_RETRIES=3
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        USER_COMMITS=$(gh api "search/commits?q=repo:$REPO+author:$USERNAME+committer-date:>=$START_DATE" --jq '.total_count' 2>&1)
        
        # Check for rate limit error
        if echo "$USER_COMMITS" | grep -q "rate limit\|API rate limit\|403"; then
          echo "  ⚠️  Rate limit hit, waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue
        fi
        
        break
      done
      
      REQUEST_COUNT=$((REQUEST_COUNT + 1))
      sleep $DELAY_SECONDS
      
      # Fetch PRs for this user with retry logic
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        USER_PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+author:$USERNAME+created:>=$START_DATE" --jq '.total_count' 2>&1)
        
        # Check for rate limit error
        if echo "$USER_PRS" | grep -q "rate limit\|API rate limit\|403"; then
          echo "  ⚠️  Rate limit hit, waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue
        fi
        
        break
      done
      
      REQUEST_COUNT=$((REQUEST_COUNT + 1))
      sleep $DELAY_SECONDS
      
      if [ -z "$USER_COMMITS" ] || ! [[ "$USER_COMMITS" =~ ^[0-9]+$ ]]; then USER_COMMITS=0; fi
      if [ -z "$USER_PRS" ] || ! [[ "$USER_PRS" =~ ^[0-9]+$ ]]; then USER_PRS=0; fi
      
      REPO_COMMITS=$((REPO_COMMITS + USER_COMMITS))
      REPO_PRS=$((REPO_PRS + USER_PRS))
    done
  else
    # No user filter - fetch all contributions (exclude dependabot)
    RETRY_COUNT=0
    MAX_RETRIES=3
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      REPO_COMMITS=$(gh api "search/commits?q=repo:$REPO+committer-date:>=$START_DATE+-author:dependabot+-author:dependabot[bot]" --jq '.total_count' 2>&1)
      
      # Check for rate limit error
      if echo "$REPO_COMMITS" | grep -q "rate limit\|API rate limit\|403"; then
        echo "  ⚠️  Rate limit hit, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      break
    done
    
    REQUEST_COUNT=$((REQUEST_COUNT + 1))
    sleep $DELAY_SECONDS
    
    # Fetch PRs with retry logic (exclude dependabot)
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      REPO_PRS=$(gh api "search/issues?q=repo:$REPO+type:pr+created:>=$START_DATE+-author:dependabot+-author:dependabot[bot]" --jq '.total_count' 2>&1)
      
      # Check for rate limit error
      if echo "$REPO_PRS" | grep -q "rate limit\|API rate limit\|403"; then
        echo "  ⚠️  Rate limit hit, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      break
    done
    
    REQUEST_COUNT=$((REQUEST_COUNT + 1))
    
    if [ -z "$REPO_COMMITS" ] || ! [[ "$REPO_COMMITS" =~ ^[0-9]+$ ]]; then REPO_COMMITS=0; fi
    if [ -z "$REPO_PRS" ] || ! [[ "$REPO_PRS" =~ ^[0-9]+$ ]]; then REPO_PRS=0; fi
  fi
  
  REPO_TOTAL=$((REPO_COMMITS + REPO_PRS))
  
  echo "  Commits: $REPO_COMMITS"
  echo "  Pull Requests: $REPO_PRS"
  echo "  Subtotal: $REPO_TOTAL"
  echo ""
  
  TOTAL_COMMITS=$((TOTAL_COMMITS + REPO_COMMITS))
  TOTAL_PRS=$((TOTAL_PRS + REPO_PRS))
  
  # Add delay between repositories
  sleep $DELAY_SECONDS
done < "$REPOS_FILE"

# Clean up temp file if using --org
if [ -n "$ORG" ]; then
  rm -f "$TEMP_REPOS_FILE"
fi

GRAND_TOTAL=$((TOTAL_COMMITS + TOTAL_PRS))

echo "============================================"
echo "SUMMARY"
echo "============================================"
echo "Total Commits: $TOTAL_COMMITS"
echo "Total Pull Requests: $TOTAL_PRS"
echo "Grand Total: $GRAND_TOTAL"
