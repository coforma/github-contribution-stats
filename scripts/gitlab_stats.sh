#!/bin/bash

# GitLab Project Contribution Stats
# Usage: GITLAB_TOKEN=your_token ./gitlab_stats.sh project-id [since-date] [--users users-file] [--url gitlab-url]

USERS_FILE=""
GITLAB_URL="https://gitlab.com"

# Parse arguments
PROJECT=""
START_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --users)
      USERS_FILE="$2"
      shift 2
      ;;
    --url)
      GITLAB_URL="$2"
      shift 2
      ;;
    *)
      if [ -z "$PROJECT" ]; then
        PROJECT="$1"
      elif [ -z "$START_DATE" ]; then
        START_DATE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT" ]; then
  echo "Usage: GITLAB_TOKEN=your_token $0 project-id [since-date] [--users users-file] [--url gitlab-url]"
  echo ""
  echo "Examples:"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 namespace/project"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 namespace/project 2025-01-01"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 namespace/project 2025-01-01 --users users.txt"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 123 --url https://gitlab.example.com"
  echo ""
  echo "project-id can be:"
  echo "  - Numeric ID (e.g., 123)"
  echo "  - URL-encoded namespace/project (e.g., namespace/project or namespace%2Fproject)"
  echo ""
  echo "If no date is provided, defaults to January 1st of the current year"
  echo "Default GitLab URL is https://gitlab.com (use --url for self-hosted)"
  exit 1
fi

# Check for GitLab token (optional for public projects)
if [ -z "$GITLAB_TOKEN" ]; then
  echo "⚠️  Warning: No GITLAB_TOKEN set - only public projects will be accessible"
  echo "For private projects, create a token at: $GITLAB_URL/-/profile/personal_access_tokens"
  echo ""
fi

# Use provided date or default to January 1st of current year
if [ -z "$START_DATE" ]; then
  CURRENT_YEAR=$(date +%Y)
  START_DATE="$CURRENT_YEAR-01-01"
fi

# URL-encode the project ID if it contains a slash
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/\//%2F/g')

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

echo "Project: $PROJECT"
echo "GitLab URL: $GITLAB_URL"
echo "Date Range: Since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by ${#USERS[@]} users from: $USERS_FILE"
fi
echo "============================================"
echo ""

DELAY_SECONDS=1
MAX_RETRIES=3

# GitLab API base URL
API_BASE="$GITLAB_URL/api/v4"

# Function to make GitLab API request
gitlab_api() {
  local endpoint="$1"
  if [ -n "$GITLAB_TOKEN" ]; then
    curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "$API_BASE/$endpoint"
  else
    curl -s "$API_BASE/$endpoint"
  fi
}

echo "=== Commits (all branches) ==="

COMMITS=0

# If users are specified, query each user individually
if [ ${#USERS[@]} -gt 0 ]; then
  for USERNAME in "${USERS[@]}"; do
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      # GitLab commits API with pagination
      PAGE=1
      USER_COMMITS=0
      
      while true; do
        RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/repository/commits?since=$START_DATE&author=$USERNAME&per_page=100&page=$PAGE")
        
        # Check for rate limit or error
        if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
          echo "⚠️  Rate limit hit for commits (user: $USERNAME), waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue 2
        fi
        
        # Check for error
        if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
          ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error // .message // "Unknown error"')
          echo "  Error for $USERNAME: $ERROR_MSG"
          break 2
        fi
        
        PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
        if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
          break
        fi
        
        USER_COMMITS=$((USER_COMMITS + PAGE_COUNT))
        
        # If we got less than 100, we're done
        if [ "$PAGE_COUNT" -lt 100 ]; then
          break
        fi
        
        PAGE=$((PAGE + 1))
      done
      
      break
    done
    
    COMMITS=$((COMMITS + USER_COMMITS))
    echo "  $USERNAME: $USER_COMMITS commits"
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all commits
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    PAGE=1
    
    while true; do
      RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/repository/commits?since=$START_DATE&per_page=100&page=$PAGE")
      
      # Check for rate limit or error
      if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
        echo "⚠️  Rate limit hit for commits, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue 2
      fi
      
      PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
      if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
        break
      fi
      
      COMMITS=$((COMMITS + PAGE_COUNT))
      
      # If we got less than 100, we're done
      if [ "$PAGE_COUNT" -lt 100 ]; then
        break
      fi
      
      PAGE=$((PAGE + 1))
    done
    
    break
  done
fi

echo "$COMMITS"

echo ""
echo "=== Merge Requests ==="

MRS=0

# If users are specified, query each user individually
if [ ${#USERS[@]} -gt 0 ]; then
  for USERNAME in "${USERS[@]}"; do
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      PAGE=1
      USER_MRS=0
      
      while true; do
        RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/merge_requests?author_username=$USERNAME&created_after=$START_DATE&per_page=100&page=$PAGE")
        
        # Check for rate limit or error
        if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
          echo "⚠️  Rate limit hit for MRs (user: $USERNAME), waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue 2
        fi
        
        # Check for error
        if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
          ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error // .message // "Unknown error"')
          echo "  Error for $USERNAME: $ERROR_MSG"
          break 2
        fi
        
        PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
        if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
          break
        fi
        
        USER_MRS=$((USER_MRS + PAGE_COUNT))
        
        # If we got less than 100, we're done
        if [ "$PAGE_COUNT" -lt 100 ]; then
          break
        fi
        
        PAGE=$((PAGE + 1))
      done
      
      break
    done
    
    MRS=$((MRS + USER_MRS))
    echo "  $USERNAME: $USER_MRS MRs"
    sleep $DELAY_SECONDS
  done
else
  # No user filter - fetch all MRs
  RETRY_COUNT=0
  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    PAGE=1
    
    while true; do
      RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/merge_requests?created_after=$START_DATE&per_page=100&page=$PAGE")
      
      # Check for rate limit or error
      if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
        echo "⚠️  Rate limit hit for MRs, waiting 60 seconds..."
        sleep 60
        RETRY_COUNT=$((RETRY_COUNT + 1))
        continue 2
      fi
      
      PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
      if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
        break
      fi
      
      MRS=$((MRS + PAGE_COUNT))
      
      # If we got less than 100, we're done
      if [ "$PAGE_COUNT" -lt 100 ]; then
        break
      fi
      
      PAGE=$((PAGE + 1))
    done
    
    break
  done
fi

echo "$MRS"

echo ""
echo "============================================"
TOTAL=$((COMMITS + MRS))
echo "Total Contributions: $TOTAL"
