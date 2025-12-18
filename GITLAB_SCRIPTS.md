# GitLab Contribution Stats Scripts

Token-based scripts for analyzing GitLab project contributions.

## Features

- **Single Project**: Get stats for one GitLab project
- **Bulk Analysis**: Analyze multiple projects and get combined totals
- **Group-Wide**: Automatically analyze all projects in a GitLab group (including subgroups)
- **User Filtering**: Filter contributions by specific GitLab usernames
- **Custom Date Ranges**: Specify a start date or default to January 1st of current year
- **Self-Hosted GitLab**: Support for both GitLab.com and self-hosted instances
- Counts commits (all branches) and merge requests authored by users
- Uses GitLab Personal Access Token for authentication

## Prerequisites

- `curl` (pre-installed on most systems)
- `jq` for JSON parsing
- GitLab Personal Access Token (PAT)

## Creating a GitLab Personal Access Token

1. Go to your GitLab instance's Personal Access Tokens page:
   - **GitLab.com**: https://gitlab.com/-/profile/personal_access_tokens
   - **Self-hosted**: `https://your-gitlab.example.com/-/profile/personal_access_tokens`

2. Click "Add new token"

3. Configure the token:
   - **Name**: `contribution-stats` (or your preference)
   - **Expiration date**: Set based on your security policy
   - **Scopes**: Select `read_api` (required)

4. Click "Create personal access token"

5. **Important**: Copy the token immediately - you won't be able to see it again!

6. Store it securely (e.g., password manager)

## Installation

```bash
# Make scripts executable
chmod +x gitlab_stats.sh gitlab_stats_bulk.sh
```

## Usage

### Single Project

Get contribution stats for a single GitLab project:

```bash
GITLAB_TOKEN=your_token ./gitlab_stats.sh project-id [since-date] [--users users-file] [--url gitlab-url]
```

**Project ID can be:**
- Namespace/project format: `mygroup/myproject`
- Numeric ID: `12345`

**Examples:**

```bash
# Use default date (January 1st of current year)
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh mygroup/myproject

# Specify a custom start date
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh mygroup/myproject 2025-01-01

# Filter by specific users
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh mygroup/myproject 2025-01-01 --users users.txt

# Use with self-hosted GitLab
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh 12345 --url https://gitlab.example.com
```

**Output:**
```
Project: mygroup/myproject
GitLab URL: https://gitlab.com
Date Range: Since 2025-01-01
Filtering by 10 users from: users.txt
============================================

=== Commits (all branches) ===
  user1: 45 commits
  user2: 32 commits
  user3: 18 commits
  ...
125

=== Merge Requests ===
  user1: 12 MRs
  user2: 8 MRs
  user3: 5 MRs
  ...
38

============================================
Total Contributions: 163
```

### Multiple Projects (Bulk)

Analyze multiple projects at once using a projects file or an entire group.

#### Option 1: Using a Projects File

1. Create a text file with projects (one per line):

```bash
cp projects.txt.example projects.txt
# Edit projects.txt with your projects
```

**projects.txt format:**
```
# Lines starting with # are comments
mygroup/project1
mygroup/project2
anothergroup/subgroup/project3
12345
```

2. Run the bulk script:

```bash
GITLAB_TOKEN=your_token ./gitlab_stats_bulk.sh projects.txt [since-date] [--users users-file] [--url gitlab-url]
```

**Examples:**

```bash
# Use default date
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh projects.txt

# With custom date
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh projects.txt 2025-01-01

# With user filtering
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh projects.txt 2025-01-01 --users users.txt

# Self-hosted GitLab
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh projects.txt --url https://gitlab.example.com
```

#### Option 2: Using a Group

Automatically analyze all projects in a GitLab group (includes subgroups):

```bash
GITLAB_TOKEN=your_token ./gitlab_stats_bulk.sh --group group-id [since-date] [--users users-file] [--url gitlab-url]
```

**Group ID can be:**
- Group path: `mygroup` or `parent-group/subgroup`
- Numeric ID: `123`

**Examples:**

```bash
# Analyze all projects in a group
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group mygroup

# With custom date
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group mygroup 2024-01-01

# With user filtering
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group mygroup 2025-01-01 --users users.txt

# Self-hosted GitLab with subgroup
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group parent/subgroup --url https://gitlab.example.com
```

**Output:**
```
Fetching projects from group: mygroup
Found 25 projects

GitLab URL: https://gitlab.com
Analyzing projects since 2025-01-01
Filtering by 10 users from: users.txt
============================================

Processing: mygroup/project1
  Commits: 125
  Merge Requests: 38
  Subtotal: 163

Processing: mygroup/project2
  Commits: 89
  Merge Requests: 22
  Subtotal: 111

...

============================================
SUMMARY
============================================
Total Commits: 543
Total Merge Requests: 187
Grand Total: 730
```

### Filtering by Users

To filter contributions by specific GitLab usernames:

1. Create a users file:

```bash
cp users.txt.example users.txt
# Edit users.txt with your GitLab usernames
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
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh mygroup/myproject --users users.txt
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh projects.txt --users users.txt
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group mygroup --users users.txt
```

## What's Counted

- **Commits**: All commits across all branches where the author matches the username
- **Merge Requests**: All MRs created by the specified users
- **Date Range**: Since the specified date or January 1st of the current year by default

**Note on Commits:** GitLab matches commits by the author field in git. If developers have different git author names/emails than their GitLab usernames, their commits may not be counted.

## Self-Hosted GitLab

Use the `--url` flag to specify your self-hosted GitLab instance:

```bash
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats.sh myproject --url https://gitlab.example.com
GITLAB_TOKEN=glpat-xxxx ./gitlab_stats_bulk.sh --group mygroup --url https://gitlab.company.com
```

Default is `https://gitlab.com` if not specified.

## Rate Limiting

GitLab has generous rate limits:

- **Default**: 2000 requests/minute for authenticated users (much higher than GitHub)
- **1-second delay** between API requests (conservative, can be reduced)
- **Automatic retry** (up to 3 attempts) when rate limits are hit
- **60-second wait** when rate limit is detected before retrying

Most users won't hit rate limits with these scripts.

## Performance

With 1-second delays between requests:

- **Single project, no users**: ~2-3 seconds
- **Single project, 10 users**: ~20 seconds (20 API calls)
- **10 projects, 10 users**: ~3-4 minutes (200 API calls)
- **25 projects, 10 users**: ~8-10 minutes (500 API calls)

Note: Pagination is handled automatically for projects with >100 commits or MRs.

## Troubleshooting

**Authentication errors:**
- Verify your token has the `read_api` scope
- Check that the token hasn't expired
- For self-hosted GitLab, ensure you're using the correct URL

**Low commit counts:**
- GitLab matches commits by git author name/email
- Check that developers' git config matches their GitLab usernames
- Merge requests are always attributed correctly to the GitLab user

**Project not found:**
- Verify the project ID or path is correct
- Ensure your token has access to the project (check visibility settings)
- For numeric IDs, make sure you're using the project ID, not the group ID

**Self-hosted GitLab issues:**
- Use `--url` flag with your GitLab instance URL
- Check that the API is accessible at `/api/v4`
- Verify SSL certificates are valid (or use `curl -k` if necessary)

## Environment Variable

You can set the token as an environment variable instead of passing it each time:

```bash
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx

./gitlab_stats.sh mygroup/myproject
./gitlab_stats_bulk.sh --group mygroup
```

## Security

- **Never commit your token** to version control
- Store tokens securely (password manager, secrets vault)
- Use tokens with minimal required scopes (`read_api` only)
- Set reasonable expiration dates
- Rotate tokens regularly

## Differences from GitHub Scripts

- Uses **Personal Access Tokens** instead of GitHub CLI
- Counts **Merge Requests** instead of Pull Requests
- Uses **pagination** instead of search API (more accurate, no 1000-result limit)
- Much **higher rate limits** (2000/min vs 30/min)
- Supports **self-hosted instances** out of the box
- Group support includes **subgroups** automatically

## License

MIT
