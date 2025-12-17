# GitHub Contribution Stats

Bash scripts to calculate contribution statistics for GitHub repositories with flexible filtering options.

## Features

- **Single Repository**: Get stats for one repository
- **Bulk Analysis**: Analyze multiple repositories and get combined totals
- **Organization-Wide**: Automatically analyze all repos in a GitHub organization
- **User Filtering**: Filter contributions by specific GitHub usernames (queries each user individually)
- **Custom Date Ranges**: Specify a start date or default to January 1st of current year
- **Rate Limit Handling**: Automatic retry logic with delays to prevent API rate limit errors
- Counts commits (all branches) and pull requests authored by users
- Uses GitHub CLI (`gh`) for API access

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- `jq` for JSON parsing (usually pre-installed on macOS)

## Installation

```bash
# Clone the repository
git clone https://github.com/coforma/github-contribution-stats.git
cd github-contribution-stats

# Make scripts executable
chmod +x github_stats.sh github_stats_bulk.sh generate_repos_file.sh
```

## Usage

### Single Repository

Get contribution stats for a single repository:

```bash
./github_stats.sh owner/repo [since-date] [--users users-file]
```

**Examples:**
```bash
# Use default date (January 1st of current year)
./github_stats.sh coforma/coforma-website-v2

# Specify a custom start date
./github_stats.sh coforma/coforma-website-v2 2024-06-01

# Filter by specific users
./github_stats.sh coforma/github-contribution-stats 2025-01-01 --users users.txt
```

**Output:**
```
Repository: coforma/github-contribution-stats
Date Range: Since 2025-01-01
Filtering by 17 users from: users.txt
============================================

=== Commits (all branches) ===
116

=== Pull Requests ===
124

============================================
Total Contributions: 240
```

### Multiple Repositories (Bulk)

Analyze multiple repositories at once using a repos file or an entire organization.

#### Option 1: Using a Repos File

1. Create a text file with repositories (one per line):

```bash
cp repos.txt.example repos.txt
# Edit repos.txt with your repositories
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
./github_stats_bulk.sh repos.txt [since-date] [--users users-file]
```

**Examples:**
```bash
# Use default date (January 1st of current year)
./github_stats_bulk.sh repos.txt

# Specify a custom start date
./github_stats_bulk.sh repos.txt 2024-06-01

# Filter by specific users
./github_stats_bulk.sh repos.txt 2025-01-01 --users users.txt
```

#### Option 2: Using an Organization

Automatically analyze all repositories in a GitHub organization:

```bash
./github_stats_bulk.sh --org <organization> [since-date] [--users users-file]
```

**Examples:**
```bash
# Analyze all repos in the organization
./github_stats_bulk.sh --org coforma

# With custom date
./github_stats_bulk.sh --org coforma 2024-01-01

# With user filtering
./github_stats_bulk.sh --org coforma 2025-01-01 --users users.txt
```

**Output:**
```
Fetching repositories from organization: coforma
Found 50 repositories

Analyzing repositories since 2025-01-01
Filtering by 17 users from: users.txt
============================================

Processing: coforma/github-contribution-stats
  Commits: 298
  Pull Requests: 357
  Subtotal: 655

Processing: coforma/usa-spending-bot
  Commits: 116
  Pull Requests: 124
  Subtotal: 240

============================================
SUMMARY
============================================
Total Commits: 414
Total Pull Requests: 481
Grand Total: 895
```

### Helper Script: Generate Repos File

Use the helper script to create a repos.txt file from an organization:

```bash
./generate_repos_file.sh <organization> [output-file]
```

**Examples:**
```bash
# Generate repos.txt from organization
./generate_repos_file.sh coforma

# Specify custom output file
./generate_repos_file.sh coforma my-repos.txt
```

This fetches up to 1000 repositories and saves them in the correct format for the bulk script.

### Filtering by Users

To filter contributions by specific GitHub usernames:

1. Create a users file:

```bash
cp users.txt.example users.txt
# Edit users.txt with your GitHub usernames
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
./github_stats.sh coforma/github-contribution-stats --users users.txt
./github_stats_bulk.sh repos.txt --users users.txt
./github_stats_bulk.sh --org coforma --users users.txt
```

**Important:** The script queries each user individually through the GitHub API. For 17 users analyzing 1 repository, this makes 34 API calls (17 for commits + 17 for PRs), which takes approximately 1 minute with the built-in rate limit delays.

## What's Counted

- **Commits**: All commits across all branches where the GitHub user is listed as the author (uses `author:username` filter)
- **Pull Requests**: All PRs created by the specified users (uses `author:username` filter)
- **Date Range**: Since the specified date or January 1st of the current year by default

**Note on Commits:** The commit count uses GitHub's `author:username` filter, which only counts commits where the git commit author email matches the user's GitHub account. If developers have mismatched git emails, their commits may not be counted.

## Advanced Usage

### Combining Options

You can combine date ranges and user filtering with either repos files or organizations:

```bash
# Repos file with users from June 1st, 2024 onwards
./github_stats_bulk.sh repos.txt 2024-06-01 --users users.txt

# Organization with custom date and user filter
./github_stats_bulk.sh --org coforma 2024-01-01 --users users.txt
```

### Parameter Order

The `--users` and `--org` flags can appear anywhere in the command, but positional arguments must be in order:
1. First positional: repository/repos file (required unless using `--org`)
2. Second positional: since-date (optional)
3. Named flags: `--users users-file` and/or `--org organization` (optional)

## Rate Limiting

The scripts include built-in rate limit handling:

- **2-second delay** between API requests
- **Automatic retry** (up to 3 attempts) when rate limits are hit
- **60-second wait** when rate limit is detected before retrying
- **GitHub Search API limits**: 30 requests/minute for authenticated users

For large teams or many repositories, the scripts will automatically slow down to stay within limits.

## Performance

Approximate execution times:

- **Single repo, no users**: ~5 seconds
- **Single repo, 17 users**: ~1 minute (34 API calls)
- **10 repos, 17 users**: ~10 minutes (340 API calls)
- **50 repos, 17 users**: ~50 minutes (1700 API calls)

## Troubleshooting

**Low commit counts compared to PRs:**
- Check that developers' git commit emails match their GitHub accounts
- Commits authored with non-matching emails won't be counted
- PRs are always attributed to the GitHub user who opened them

**Rate limit errors:**
- The scripts have automatic retry logic
- If you consistently hit limits, they will wait 60 seconds and retry
- For very large organizations, consider running during off-peak hours

## Customization

The scripts automatically default to January 1st of the current year, but you can specify any date in `YYYY-MM-DD` format as a parameter. User filtering is optional and can be applied to narrow results to specific contributors.

## License

MIT

## Contributing

Pull requests welcome! For major changes, please open an issue first to discuss what you would like to change.
