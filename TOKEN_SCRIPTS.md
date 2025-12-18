# Token-Based Scripts for WSL/Environments without GitHub CLI

These scripts work identically to the main scripts but use a GitHub personal access token instead of the GitHub CLI (`gh`). This makes them compatible with WSL, Git Bash, and any environment with `curl` and `jq`.

## Setup

1. **Create a GitHub Personal Access Token:**
   - Go to https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Give it a name (e.g., "GitHub Stats")
   - Select scopes:
     - For public repos: `public_repo`
     - For private repos: `repo` (full repo access)
   - Click "Generate token" and copy it

2. **Set the token as an environment variable:**

   ```bash
   # For single use (works in WSL, Git Bash, Linux, macOS)
   export GITHUB_TOKEN=ghp_your_token_here
   
   # Or pass it inline with the command
   GITHUB_TOKEN=ghp_your_token_here ./github_stats_token.sh owner/repo
   ```

## Usage

### Single Repository

```bash
# Basic usage
GITHUB_TOKEN=ghp_xxxx ./github_stats_token.sh coforma/github-contribution-stats

# With custom date
GITHUB_TOKEN=ghp_xxxx ./github_stats_token.sh coforma/github-contribution-stats 2024-01-01

# With user filtering
GITHUB_TOKEN=ghp_xxxx ./github_stats_token.sh coforma/github-contribution-stats 2025-01-01 --users users.txt
```

### Bulk Analysis

```bash
# Using repos file
GITHUB_TOKEN=ghp_xxxx ./github_stats_bulk_token.sh repos.txt

# With custom date and users
GITHUB_TOKEN=ghp_xxxx ./github_stats_bulk_token.sh repos.txt 2024-01-01 --users users.txt

# Using organization
GITHUB_TOKEN=ghp_xxxx ./github_stats_bulk_token.sh --org coforma

# Organization with custom date and users
GITHUB_TOKEN=ghp_xxxx ./github_stats_bulk_token.sh --org coforma 2025-01-01 --users users.txt
```

## Differences from Main Scripts

- **Authentication**: Uses `GITHUB_TOKEN` environment variable instead of `gh` CLI
- **Dependencies**: Requires `curl` and `jq` (no GitHub CLI needed)
- **Functionality**: Identical behavior and output to main scripts
- **Rate Limits**: Same rate limiting and retry logic

## For Windows Users (WSL/Git Bash)

These scripts work in:
- **WSL (Windows Subsystem for Linux)**: Install `jq` with `sudo apt install jq`
- **Git Bash**: Install `jq` from https://stedolan.github.io/jq/download/
- **Cygwin**: Install `curl` and `jq` packages

## Requirements

- `bash` (4.0+)
- `curl` (for API requests)
- `jq` (for JSON parsing)
- GitHub Personal Access Token

## Security Note

**Never commit your token to git!** The `.gitignore` file excludes common token files, but be careful not to accidentally share your token.
