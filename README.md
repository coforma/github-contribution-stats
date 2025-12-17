# GitHub Contribution Stats

Simple bash scripts to calculate contribution statistics for GitHub repositories since January 1, 2025.

## Features

- **Single Repository**: Get stats for one repository
- **Bulk Analysis**: Analyze multiple repositories and get combined totals
- **Organization-Wide**: Automatically analyze all repos in a GitHub organization
- **User Filtering**: Filter contributions by specific GitHub usernames
- **Custom Date Ranges**: Specify a start date or default to January 1st of current year
- Counts commits (all branches) and pull requests
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
chmod +x github_stats.sh github_stats_bulk.sh
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
./github_stats.sh coforma/coforma-website-v2 2025-01-01 --users users.txt
```

**Output:**
```
Repository: coforma/coforma-website-v2
Date Range: Since January 1, 2025
============================================

=== Commits (all branches) ===
116

=== Pull Requests ===
124

============================================
Total Contributions: 240
```

### Multiple Repositories (Bulk)

Analyze multiple repositories at once using a repos file or an entire organization:

#### Using a Repos File

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

#### Using an Organization

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
Analyzing repositories since January 1, 2025
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
```

This will count only commits and pull requests authored by the specified users.

## What's Counted

- **Commits**: All commits across all branches authored by specified users (or all users if no filter)
- **Pull Requests**: All PRs created by specified users (or all users if no filter)
- **Date Range**: Since the specified date or January 1st of the current year by default

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

## Customization

The scripts automatically default to January 1st of the current year, but you can specify any date in `YYYY-MM-DD` format as a parameter. User filtering is optional and can be applied to narrow results to specific contributors.

## License

MIT

## Contributing

Pull requests welcome! For major changes, please open an issue first to discuss what you would like to change.
