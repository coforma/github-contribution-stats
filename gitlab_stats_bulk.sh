#!/bin/bash

# GitLab Bulk Contribution Stats
# Usage: GITLAB_TOKEN=your_token ./gitlab_stats_bulk.sh projects-file [since-date] [--users users-file] [--url gitlab-url]
# Or:    GITLAB_TOKEN=your_token ./gitlab_stats_bulk.sh --group group-id [since-date] [--users users-file] [--url gitlab-url]

USERS_FILE=""
PROJECTS_FILE=""
GROUP=""
GITLAB_URL="https://gitlab.com"

# Parse arguments
START_DATE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --users)
      USERS_FILE="$2"
      shift 2
      ;;
    --group)
      GROUP="$2"
      shift 2
      ;;
    --url)
      GITLAB_URL="$2"
      shift 2
      ;;
    *)
      if [ -z "$PROJECTS_FILE" ] && [ -z "$GROUP" ]; then
        PROJECTS_FILE="$1"
      elif [ -z "$START_DATE" ]; then
        START_DATE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECTS_FILE" ] && [ -z "$GROUP" ]; then
  echo "Usage: GITLAB_TOKEN=your_token $0 projects-file [since-date] [--users users-file] [--url gitlab-url]"
  echo "   Or: GITLAB_TOKEN=your_token $0 --group group-id [since-date] [--users users-file] [--url gitlab-url]"
  echo ""
  echo "Examples:"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 projects.txt"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 projects.txt 2025-01-01"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 projects.txt 2025-01-01 --users users.txt"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 --group mygroup"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 --group mygroup 2025-01-01 --users users.txt"
  echo "  GITLAB_TOKEN=glpat-xxxx $0 --group 123 --url https://gitlab.example.com"
  echo ""
  echo "File format: one project per line (namespace/project or numeric ID)"
  echo "If no date is provided, defaults to January 1st of the current year"
  echo "Default GitLab URL is https://gitlab.com (use --url for self-hosted)"
  exit 1
fi

if [ -n "$PROJECTS_FILE" ] && [ -n "$GROUP" ]; then
  echo "Error: Cannot use both projects-file and --group flag"
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

# If using --group flag, fetch all projects from the group
if [ -n "$GROUP" ]; then
  echo "Fetching projects from group: $GROUP"
  GROUP_ENCODED=$(echo "$GROUP" | sed 's/\//%2F/g')
  TEMP_PROJECTS_FILE=$(mktemp)
  
  PAGE=1
  while true; do
    RESPONSE=$(gitlab_api "groups/$GROUP_ENCODED/projects?per_page=100&page=$PAGE&include_subgroups=true")
    PROJECTS=$(echo "$RESPONSE" | jq -r '.[].path_with_namespace' 2>/dev/null)
    
    if [ -z "$PROJECTS" ]; then
      break
    fi
    
    echo "$PROJECTS" >> "$TEMP_PROJECTS_FILE"
    
    # Check if there are more pages
    if [ $(echo "$RESPONSE" | jq '. | length') -lt 100 ]; then
      break
    fi
    
    PAGE=$((PAGE + 1))
  done
  
  if [ ! -s "$TEMP_PROJECTS_FILE" ]; then
    echo "Error: Failed to fetch projects from group '$GROUP'"
    rm -f "$TEMP_PROJECTS_FILE"
    exit 1
  fi
  
  PROJECTS_FILE="$TEMP_PROJECTS_FILE"
  PROJECT_COUNT=$(wc -l < "$TEMP_PROJECTS_FILE" | tr -d ' ')
  echo "Found $PROJECT_COUNT projects"
  echo ""
fi

if [ ! -f "$PROJECTS_FILE" ]; then
  echo "Error: File '$PROJECTS_FILE' not found"
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

echo "GitLab URL: $GITLAB_URL"
echo "Analyzing projects since $START_DATE"
if [ -n "$USERS_FILE" ]; then
  echo "Filtering by ${#USERS[@]} users from: $USERS_FILE"
fi
echo "============================================"
echo ""

TOTAL_COMMITS=0
TOTAL_MRS=0
DELAY_SECONDS=1
MAX_RETRIES=3

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
  # Skip empty lines and comments
  [[ -z "$PROJECT" || "$PROJECT" =~ ^[[:space:]]*# ]] && continue
  
  echo "Processing: $PROJECT"
  
  PROJECT_COMMITS=0
  PROJECT_MRS=0
  
  # URL-encode the project ID
  PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/\//%2F/g')
  
  # If users are specified, query each user individually
  if [ ${#USERS[@]} -gt 0 ]; then
    for USERNAME in "${USERS[@]}"; do
      # Fetch commits for this user with retry logic
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        PAGE=1
        USER_COMMITS=0
        
        while true; do
          RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/repository/commits?since=$START_DATE&author=$USERNAME&per_page=100&page=$PAGE")
          
          # Check for rate limit or error
          if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
            echo "  ⚠️  Rate limit hit for commits (user: $USERNAME), waiting 60 seconds..."
            sleep 60
            RETRY_COUNT=$((RETRY_COUNT + 1))
            continue 3
          fi
          
          # Check for error (skip user if project not accessible)
          if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
            break 2
          fi
          
          PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
          if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
            break
          fi
          
          USER_COMMITS=$((USER_COMMITS + PAGE_COUNT))
          
          if [ "$PAGE_COUNT" -lt 100 ]; then
            break
          fi
          
          PAGE=$((PAGE + 1))
        done
        
        break
      done
      
      sleep $DELAY_SECONDS
      
      # Fetch MRs for this user with retry logic
      RETRY_COUNT=0
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        PAGE=1
        USER_MRS=0
        
        while true; do
          RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/merge_requests?author_username=$USERNAME&created_after=$START_DATE&per_page=100&page=$PAGE")
          
          # Check for rate limit or error
          if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
            echo "  ⚠️  Rate limit hit for MRs (user: $USERNAME), waiting 60 seconds..."
            sleep 60
            RETRY_COUNT=$((RETRY_COUNT + 1))
            continue 3
          fi
          
          # Check for error (skip user if project not accessible)
          if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
            break 2
          fi
          
          PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
          if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
            break
          fi
          
          USER_MRS=$((USER_MRS + PAGE_COUNT))
          
          if [ "$PAGE_COUNT" -lt 100 ]; then
            break
          fi
          
          PAGE=$((PAGE + 1))
        done
        
        break
      done
      
      sleep $DELAY_SECONDS
      
      PROJECT_COMMITS=$((PROJECT_COMMITS + USER_COMMITS))
      PROJECT_MRS=$((PROJECT_MRS + USER_MRS))
    done
  else
    # No user filter - fetch all contributions
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      PAGE=1
      
      while true; do
        RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/repository/commits?since=$START_DATE&per_page=100&page=$PAGE")
        
        # Check for rate limit or error
        if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
          echo "  ⚠️  Rate limit hit for commits, waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue 2
        fi
        
        # Check for error (skip if project not accessible)
        if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
          break 2
        fi
        
        PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
        if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
          break
        fi
        
        PROJECT_COMMITS=$((PROJECT_COMMITS + PAGE_COUNT))
        
        if [ "$PAGE_COUNT" -lt 100 ]; then
          break
        fi
        
        PAGE=$((PAGE + 1))
      done
      
      break
    done
    
    sleep $DELAY_SECONDS
    
    # Fetch MRs with retry logic
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      PAGE=1
      
      while true; do
        RESPONSE=$(gitlab_api "projects/$PROJECT_ENCODED/merge_requests?created_after=$START_DATE&per_page=100&page=$PAGE")
        
        # Check for rate limit or error
        if echo "$RESPONSE" | jq -e '.message' 2>/dev/null | grep -qi "rate limit\|429"; then
          echo "  ⚠️  Rate limit hit for MRs, waiting 60 seconds..."
          sleep 60
          RETRY_COUNT=$((RETRY_COUNT + 1))
          continue 2
        fi
        
        # Check for error (skip if project not accessible)
        if echo "$RESPONSE" | jq -e '.error' 2>/dev/null >/dev/null; then
          break 2
        fi
        
        PAGE_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null)
        if [ -z "$PAGE_COUNT" ] || [ "$PAGE_COUNT" -eq 0 ]; then
          break
        fi
        
        PROJECT_MRS=$((PROJECT_MRS + PAGE_COUNT))
        
        if [ "$PAGE_COUNT" -lt 100 ]; then
          break
        fi
        
        PAGE=$((PAGE + 1))
      done
      
      break
    done
    
    sleep $DELAY_SECONDS
  fi
  
  echo "  Commits: $PROJECT_COMMITS"
  echo "  Merge Requests: $PROJECT_MRS"
  PROJECT_TOTAL=$((PROJECT_COMMITS + PROJECT_MRS))
  echo "  Subtotal: $PROJECT_TOTAL"
  echo ""
  
  TOTAL_COMMITS=$((TOTAL_COMMITS + PROJECT_COMMITS))
  TOTAL_MRS=$((TOTAL_MRS + PROJECT_MRS))
  
done < "$PROJECTS_FILE"

# Clean up temp file if we created one
if [ -n "$GROUP" ]; then
  rm -f "$TEMP_PROJECTS_FILE"
fi

echo "============================================"
echo "SUMMARY"
echo "============================================"
echo "Total Commits: $TOTAL_COMMITS"
echo "Total Merge Requests: $TOTAL_MRS"
GRAND_TOTAL=$((TOTAL_COMMITS + TOTAL_MRS))
echo "Grand Total: $GRAND_TOTAL"
