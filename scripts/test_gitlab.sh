#!/bin/bash
# Quick test of GitLab API without token (public projects only)

PROJECT="gitlab-org/gitlab-runner"
PROJECT_ENCODED=$(echo "$PROJECT" | sed 's/\//%2F/g')
START_DATE="2025-01-01"

echo "Testing GitLab API with public project: $PROJECT"
echo "Date: Since $START_DATE"
echo ""

# Test commits
echo "Fetching commits..."
RESPONSE=$(curl -s "https://gitlab.com/api/v4/projects/$PROJECT_ENCODED/repository/commits?since=$START_DATE&per_page=5")
COMMIT_COUNT=$(echo "$RESPONSE" | jq '. | length')
echo "Sample commits found: $COMMIT_COUNT"
echo ""

# Test merge requests
echo "Fetching merge requests..."
RESPONSE=$(curl -s "https://gitlab.com/api/v4/projects/$PROJECT_ENCODED/merge_requests?created_after=$START_DATE&per_page=5")
MR_COUNT=$(echo "$RESPONSE" | jq '. | length')
echo "Sample MRs found: $MR_COUNT"
echo ""

echo "✓ GitLab API is working!"
echo ""
echo "To run the full script on this project:"
echo "  GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh gitlab-org/gitlab-runner 2025-01-01"
