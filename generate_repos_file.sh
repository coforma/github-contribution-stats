#!/bin/bash

# Generate repos.txt file from GitHub organization
# Usage: ./generate_repos_file.sh <organization> [output-file]

if [ -z "$1" ]; then
  echo "Usage: $0 <organization> [output-file]"
  echo "Example: $0 coforma"
  echo "Example: $0 coforma my-repos.txt"
  echo ""
  echo "If no output file is specified, defaults to repos.txt"
  exit 1
fi

ORG="$1"
OUTPUT_FILE="${2:-repos.txt}"

echo "Fetching repositories from organization: $ORG"

# Fetch all repos from the organization
gh repo list "$ORG" --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' > "$OUTPUT_FILE" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch repositories from organization '$ORG'"
  echo "Make sure you have access to the organization and gh CLI is authenticated"
  exit 1
fi

if [ ! -s "$OUTPUT_FILE" ]; then
  echo "Error: No repositories found for organization '$ORG'"
  rm -f "$OUTPUT_FILE"
  exit 1
fi

REPO_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

echo "✓ Successfully fetched $REPO_COUNT repositories"
echo "✓ Saved to: $OUTPUT_FILE"
echo ""
echo "You can now run:"
echo "  ./github_stats_bulk.sh $OUTPUT_FILE"
