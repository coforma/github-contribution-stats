# GitHub Contribution Stats

Simple bash scripts to calculate contribution statistics for GitHub repositories since January 1, 2025.

## Features

- **Single Repository**: Get stats for one repository
- **Bulk Analysis**: Analyze multiple repositories and get combined totals
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
./github_stats.sh owner/repo
```

**Example:**
```bash
./github_stats.sh coforma/coforma-website-v2
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

Analyze multiple repositories at once:

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
./github_stats_bulk.sh repos.txt
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

## What's Counted

- **Commits**: All commits across all branches (not just the default branch)
- **Pull Requests**: All PRs created since January 1, 2025
- **Date Range**: Hardcoded to January 1, 2025 onwards

## Customization

To change the start date, edit the `START_DATE` variable in either script:

```bash
START_DATE="2025-01-01"  # Change to your desired date
```

## License

MIT

## Contributing

Pull requests welcome! For major changes, please open an issue first to discuss what you would like to change.
