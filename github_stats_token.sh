#!/bin/bash

# GitHub Repository Contribution Stats (Token-based)
# Usage: GITHUB_TOKEN=your_token ./github_stats_token.sh owner/repo [since-date] [--users users-file] [--ignore ignore-file]

USERS_FILE=""
IGNORE_FILE=""

# Parse arguments
REPO=""
START_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --users)
      USERS_FILE="$2"
      shift 2
      ;;
    --ignore)
      IGNORE_FILE="$2"
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
  echo "Usage: GITHUB_TOKEN=your_token $0 owner/repo [since-date] [--users users-file] [--ignore ignore-file]"
  echo "Example: GITHUB_TOKEN=ghp_xxxx $0 coforma/github-contribution-stats"
  echo "Example: GITHUB_TOKEN=ghp_xxxx $0 coforma/github-contribution-stats 2025-01-01"
  echo "Example: GITHUB_TOKEN=ghp_xxxx $0 coforma/github-contribution-stats 2025-01-01 --users users.txt"
  echo "Example: GITHUB_TOKEN=ghp_xxxx $0 coforma/github-contribution-stats 2025-01-01 --ignore ignore_authors.txt"
  echo "If no date is provided, defaults to January 1st of the current year"
  exit 1
fi

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN environment variable is required"
  echo "Create a token at: https://github.com/settings/tokens"
  echo "Required scopes: public_repo (or repo for private repos)"
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

# Load ignore list into array if ignore file is provided
IGNORE_AUTHORS=()
if [ -n "$IGNORE_FILE" ]; then
  if [ ! -f "$IGNORE_FILE" ]; then
    echo "Error: Ignore file '$IGNORE_FILE' not found"
    exit 1
  fi
  
  while IFS= read -r USERNAME || [ -n "$USERNAME" ]; do
    # Skip empty lines and comments
    [[ -z "$USERNAME" || "$USERNAME" =~ ^[[:space:]]*# ]] && continue
    IGNORE_AUTHORS+=("$USERNAME")
  done < "$IGNORE_FILE"
fi

echo "Repository: $REPO"
echo "Date Range: Since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by ${#USERS[@]} users from: $USERS_FILE"
fi
if [ -n "$IGNORE_FILE" ]; then
  echo "Ignoring ${#IGNORE_AUTHORS[@]} authors from: $IGNORE_FILE"
fi
echo "============================================"
echo ""

DELAY_SECONDS=3
MAX_RETRIES=3

# GitHub API base URL
API_BASE="https://api.github.com"

# Function to make GitHub API request
github_api() {
  local endpoint="$1"
  local extra_header="$2"
  
  if [ -n "$extra_header" ]; then
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.cloak-preview+json" \
         -H "$extra_header" \
         "$API_BASE/$endpoint"
  else
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         "$API_BASE/$endpoint"
  fi
}

# Function to URL encode a string
urlencode() {
  local string="$1"
  echo "$string" | jq -sRr @uri
}

echo "=== Commits (all branches) ==="

COMMITS=0

# If users are specified, query each user individually
if [ ${#USERS[@]} -gt 0 ]; then
  for USERNAME in "${USERS[@]}"; do
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      QUERY="repo:$REPO author:$USERNAME committer-date:>=$START_DATE"
      RESPONSE=$(github_api "search/commits?q=$(urlencode "$QUERY")" "Accept: application/vnd.github.cloak-preview")
      
      # Check for rate limit error in API response (not in commit messages)
      if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|API rate limit"; then
        echo "⚠️  Rate limit hit for commits (user: $USERNAME), waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      USER_COMMITS=$(echo "$RESPONSE" | jq -r '.total_count // 0')
      break
    done
    
    if [ -z "$USER_COMMITS" ] || ! [[ "$USER_COMMITS" =~ ^[0-9]+$ ]]; then USER_COMMITS=0; fi
    COMMITS=$((COMMITS + USER_COMMITS))
    echo "  $USERNAME: $USER_COMMITS commits"
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all contributions (exclude ignored authors)
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    QUERY="repo:$REPO committer-date:>=$START_DATE"
    # Add ignore filters
    if [ ${#IGNORE_AUTHORS[@]} -gt 0 ]; then
      for IGNORE_USER in "${IGNORE_AUTHORS[@]}"; do
        QUERY="$QUERY -author:$IGNORE_USER"
      done
    fi
    RESPONSE=$(github_api "search/commits?q=$(urlencode "$QUERY")" "Accept: application/vnd.github.cloak-preview")
    
    # Check for rate limit error in API response (not in commit messages)
    if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|API rate limit"; then
      echo "⚠️  Rate limit hit for commits, waiting 60 seconds..."
      sleep 60
      RETRY_COUNT=$((RETRY_COUNT + 1))
      continue
    fi
    
    COMMITS=$(echo "$RESPONSE" | jq -r '.total_count // 0')
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
      QUERY="repo:$REPO type:pr author:$USERNAME created:>=$START_DATE"
      RESPONSE=$(github_api "search/issues?q=$(urlencode "$QUERY")")
      
      # Check for rate limit error in API response (not in commit messages)
      if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|API rate limit"; then
        echo "⚠️  Rate limit hit for PRs (user: $USERNAME), waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue
      fi
      
      USER_PRS=$(echo "$RESPONSE" | jq -r '.total_count // 0')
      break
    done
    
    if [ -z "$USER_PRS" ] || ! [[ "$USER_PRS" =~ ^[0-9]+$ ]]; then USER_PRS=0; fi
    PRS=$((PRS + USER_PRS))
    echo "  $USERNAME: $USER_PRS PRs"
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all contributions (exclude ignored authors)
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    QUERY="repo:$REPO type:pr created:>=$START_DATE"
    # Add ignore filters
    if [ ${#IGNORE_AUTHORS[@]} -gt 0 ]; then
      for IGNORE_USER in "${IGNORE_AUTHORS[@]}"; do
        QUERY="$QUERY -author:$IGNORE_USER"
      done
    fi
    RESPONSE=$(github_api "search/issues?q=$(urlencode "$QUERY")")
    
    # Check for rate limit error in API response (not in commit messages)
    if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|API rate limit"; then
      echo "⚠️  Rate limit hit for PRs, waiting 60 seconds..."
      sleep 60
      RETRY_COUNT=$((RETRY_COUNT + 1))
      continue
    fi
    
    PRS=$(echo "$RESPONSE" | jq -r '.total_count // 0')
    break
  done
  
  if [ -z "$PRS" ] || ! [[ "$PRS" =~ ^[0-9]+$ ]]; then PRS=0; fi
fi

echo "$PRS"

echo ""
echo "============================================"
TOTAL=$((COMMITS + PRS))
echo "Total Contributions: $TOTAL"
