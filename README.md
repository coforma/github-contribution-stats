# GitHub Contribution Stats

Bash scripts to calculate contribution statistics for GitHub and GitLab repositories with flexible filtering options.

## Features

- **GitHub & GitLab Support**: Scripts for both platforms
- **Single Repository/Project**: Get stats for one repo/project
- **Bulk Analysis**: Analyze multiple repositories/projects and get combined totals
- **Organization/Group-Wide**: Automatically analyze all repos in a GitHub org or GitLab group
- **User Filtering**: Filter contributions by specific usernames (queries each user individually)
- **Custom Date Ranges**: Specify a start date or default to January 1st of current year
- **Rate Limit Handling**: Automatic retry logic with delays to prevent API rate limit errors
- **Cross-Platform**: Token-based scripts for WSL/Git Bash environments
- Counts commits (all branches) and pull requests/merge requests authored by users

## Quick Start

**GitHub:**
- CLI-based: `./scripts/github_stats.sh owner/repo`
- Token-based: `GITHUB_TOKEN=xxx ./scripts/github_stats_token.sh owner/repo`

**GitLab:**
- `GITLAB_TOKEN=xxx ./scripts/gitlab_stats.sh namespace/project`

See platform-specific documentation:
- [GitHub Scripts Documentation](#github-scripts) (this file)
- [GitLab Scripts Documentation](docs/GITLAB_SCRIPTS.md)
- [Token-Based Scripts for WSL/Git Bash](docs/TOKEN_SCRIPTS.md)

---

## GitHub Scripts

## Prerequisites

### For GitHub CLI Scripts (`github_stats.sh` and `github_stats_bulk.sh`)

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- `jq` for JSON parsing (usually pre-installed on macOS)

### For Token-Based Scripts (`github_stats_token.sh` and `github_stats_bulk_token.sh`)

- `curl` (pre-installed on most systems)
- `jq` for JSON parsing
- GitHub Personal Access Token (PAT)
- Works on WSL, Git Bash, macOS, Linux

See [docs/TOKEN_SCRIPTS.md](docs/TOKEN_SCRIPTS.md) for detailed token-based script documentation.

## Installation

```bash
# Clone the repository
git clone https://github.com/coforma/github-contribution-stats.git
cd github-contribution-stats

# Make scripts executable
chmod +x scripts/*.sh
```

## Usage

### Choosing the Right Script

- **GitHub CLI Scripts** (`github_stats.sh`, `github_stats_bulk.sh`): Use if you have GitHub CLI installed and authenticated
- **Token-Based Scripts** (`github_stats_token.sh`, `github_stats_bulk_token.sh`): Use for WSL, Git Bash, or environments without GitHub CLI

Both versions have identical functionality. See [docs/TOKEN_SCRIPTS.md](docs/TOKEN_SCRIPTS.md) for token-based script usage.

### Single Repository

Get contribution stats for a single repository:

```bash
./scripts/github_stats.sh owner/repo [since-date] [--users users-file] [--ignore ignore-file]
```

**Examples:**
```bash
# Use default date (January 1st of current year)
./scripts/github_stats.sh coforma/coforma-website-v2

# Specify a custom start date
./scripts/github_stats.sh coforma/coforma-website-v2 2024-06-01

# Filter by specific users
./scripts/github_stats.sh coforma/github-contribution-stats 2025-01-01 --users data/users.txt
```

**Output:**
```
Repository: coforma/github-contribution-stats
Date Range: Since 2025-01-01
Filtering by 17 users from: data/users.txt
============================================

=== Pull Requests ===
124
```

### Multiple Repositories (Bulk)

Analyze multiple repositories at once using a repos file or an entire organization.

#### Option 1: Using a Repos File

1. Create a text file with repositories (one per line):

```bash
cp examples/repos.txt.example data/repos.txt
# Edit data/repos.txt with your repositories
```

**repos.txt format:**
```
# Lines starting with # are comments
coforma/github-contribution-stats
coforma/usa-spending-bot
your-org/your-repo
```

2. Run the bulk script:

```bash
./scripts/github_stats_bulk.sh data/repos.txt [since-date] [--users data/users.txt] [--ignore data/ignore_authors.txt]
```

**Examples:**
```bash
# Use default date (January 1st of current year)
./scripts/github_stats_bulk.sh data/repos.txt

# Specify a custom start date
./scripts/github_stats_bulk.sh data/repos.txt 2024-06-01

# Filter by specific users
./scripts/github_stats_bulk.sh data/repos.txt 2025-01-01 --users data/users.txt
```

#### Option 2: Using an Organization

Automatically analyze all repositories in a GitHub organization:

```bash
./scripts/github_stats_bulk.sh --org <organization> [since-date] [--users data/users.txt] [--ignore data/ignore_authors.txt]
```

**Examples:**
```bash
# Analyze all repos in the organization
./scripts/github_stats_bulk.sh --org coforma

# With custom date
./scripts/github_stats_bulk.sh --org coforma 2024-01-01

# With user filtering and ignore list
./scripts/github_stats_bulk.sh --org coforma 2025-01-01 --users data/users.txt --ignore data/ignore_authors.txt
```

**Output:**
```
Fetching repositories from organization: coforma
Found 50 repositories

Analyzing repositories since 2025-01-01
Filtering by 17 users from: data/users.txt
============================================

Processing: coforma/github-contribution-stats
  Pull Requests: 357

Processing: coforma/usa-spending-bot
  Pull Requests: 124

============================================
SUMMARY
============================================
Total Pull Requests: 481
```

### Helper Script: Generate Repos File

Use the helper script to create a repos.txt file from an organization:

```bash
./scripts/generate_repos_file.sh <organization> [output-file]
```

**Examples:**
```bash
# Generate repos.txt from organization
./scripts/generate_repos_file.sh coforma data/repos.txt

# Specify custom output file
./scripts/generate_repos_file.sh coforma data/my-repos.txt
```

This fetches up to 1000 repositories and saves them in the correct format for the bulk script.

### Filtering by Users

To filter contributions by specific GitHub usernames:

1. Create a users file:

```bash
cp examples/users.txt.example data/users.txt
# Edit data/users.txt with your GitHub usernames
```

**users.txt format:**
```
# Lines starting with # are comments
username1
username2
username3
```

2. Use the `--users` flag with either script:

```bash
./scripts/github_stats.sh coforma/github-contribution-stats --users data/users.txt
./scripts/github_stats_bulk.sh data/repos.txt --users data/users.txt
./scripts/github_stats_bulk.sh --org coforma --users data/users.txt
```

**Important:** The script queries each user individually through the GitHub API. For 17 users analyzing 1 repository, this makes 34 API calls (17 for PRs), which takes approximately 30 seconds with the built-in rate limit delays.

### Ignoring Authors (Bot Accounts)

To exclude bot accounts like dependabot or renovate from your statistics:

1. Create an ignore authors file:

```bash
cp examples/ignore_authors.txt.example data/ignore_authors.txt
# Edit data/ignore_authors.txt with authors to exclude
```

**ignore_authors.txt format:**
```
# Lines starting with # are comments
# One author per line
dependabot
dependabot[bot]
renovate[bot]
github-actions[bot]
```

2. Use the `--ignore` flag with any script:

```bash
./scripts/github_stats.sh coforma/github-contribution-stats --ignore data/ignore_authors.txt
./scripts/github_stats_bulk.sh data/repos.txt --ignore data/ignore_authors.txt
./scripts/github_stats_bulk.sh --org coforma --ignore data/ignore_authors.txt
```

**Note:** The ignore filter is only applied when NOT using `--users`. If you specify users, only those users are counted (ignore list is not needed).

## What's Counted

- **Pull Requests**: All PRs created by the specified users (uses `author:username` filter)
- **Date Range**: Since the specified date or January 1st of the current year by default
- **Exclusions**: When using `--ignore`, bot accounts and automated contributors are excluded from counts

## Advanced Usage

### Combining Options

You can combine date ranges and user filtering with either repos files or organizations:

```bash
# Repos file with users from June 1st, 2024 onwards
./scripts/github_stats_bulk.sh data/repos.txt 2024-06-01 --users data/users.txt

# Organization with custom date, user filter, and ignore list
./scripts/github_stats_bulk.sh --org coforma 2024-01-01 --users data/users.txt --ignore data/ignore_authors.txt
```

### Parameter Order

The `--users` and `--org` flags can appear anywhere in the command, but positional arguments must be in order:
1. First positional: repository/repos file (required unless using `--org`)
2. Second positional: since-date (optional)
3. Named flags: `--users users-file` and/or `--org organization` (optional)

## Rate Limiting

The scripts include built-in rate limit handling:

- **3-second delay** between API requests (to stay well under the 30 requests/minute limit)
- **Automatic retry** (up to 3 attempts) when rate limits are hit
- **60-second wait** when rate limit is detected before retrying
- **GitHub Search API limits**: 30 requests/minute for authenticated users
- **Improved error detection**: Only triggers on actual API rate limit errors (not commit messages containing "rate limit")

For large teams or many repositories, the scripts will automatically slow down to stay within limits.

## Performance

Approximate execution times (with 3-second delays between requests):

- **Single repo, no users**: ~4 seconds
- **Single repo, 17 users**: ~1 minute (17 API calls)
- **10 repos, 17 users**: ~6 minutes (170 API calls)
- **50 repos, 17 users**: ~28 minutes (850 API calls)

## Troubleshooting

**Rate limit errors:**
- The scripts have automatic retry logic with improved error detection
- Rate limit detection now only triggers on actual API errors (fixed false positives from commit messages)
- If you consistently hit limits, they will wait 60 seconds and retry
- For very large organizations, consider running during off-peak hours

**WSL or Git Bash environments:**
- Use the token-based scripts (`scripts/github_stats_token.sh`, `scripts/github_stats_bulk_token.sh`)
- See [docs/TOKEN_SCRIPTS.md](docs/TOKEN_SCRIPTS.md) for setup instructions
- Requires a GitHub Personal Access Token instead of GitHub CLI

## Customization

The scripts automatically default to January 1st of the current year, but you can specify any date in `YYYY-MM-DD` format as a parameter. User filtering is optional and can be applied to narrow results to specific contributors.

## License

MIT

## Contributing

Pull requests welcome! For major changes, please open an issue first to discuss what you would like to change.
