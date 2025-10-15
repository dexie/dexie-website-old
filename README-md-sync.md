# MD Files Historical Sync Scripts

These scripts allow you to extract and apply MD file changes from a commit range in the dexie-website repository to the dexie-web-mui repository.

## Prerequisites

- Both repositories should be cloned at the same directory level:
  ```
  parent-directory/
  ├── dexie-website/
  └── dexie-web-mui/
  ```
- `jq` is recommended but not required (the scripts have fallback parsing)

## Usage

### 1. Extract MD changes from a commit range

```bash
./extract-md-changes.sh <start-commit-hash>
```

**Example:**

```bash
./extract-md-changes.sh abc123def
```

**What it does:**

- Analyzes all commits from the specified start commit to HEAD for MD file changes
- Generates cumulative `.patch` files for each changed MD file across the entire range
- Creates a manifest file with commit range metadata
- Stores everything in `diffs/` directory

**Output files:**

- `diffs/<start>_to_HEAD_<filename>.patch` - Individual patch files
- `diffs/<start>_to_HEAD_manifest.json` - Metadata about the commit range

### 2. Apply changes to target repository

```bash
./apply-md-changes.sh <start-commit-hash>
```

**Example:**

```bash
./apply-md-changes.sh abc123def
```

**What it does:**

- Reads the generated patches from step 1
- Applies them to the corresponding files in `../dexie-web-mui/`
- Handles file additions, modifications, and deletions
- Uses 3-way merge as fallback for conflicts
- Creates a commit with detailed metadata about the commit range

## Features

### Smart Patch Application

- **File modifications**: Uses `git apply` with 3-way merge fallback
- **File additions**: Creates new files and directory structure as needed
- **File deletions**: Removes files from the target repository
- **Conflict handling**: Attempts 3-way merge when direct patch fails

### Detailed Logging

- Shows progress for each file being processed
- Reports successful applications, failures, and the reasons
- Provides comprehensive summary of all changes

### Commit Range Processing

- Extracts **all changes** from a starting commit to HEAD, not just individual commits
- Provides cumulative diff that shows the net effect of all changes in the range
- Useful for syncing large batches of historical changes

## Example Workflow

```bash
# 1. Find a starting point for the changes you want to sync
git log --oneline --name-only | grep -B1 '\.md$'

# 2. Extract all changes from that commit to HEAD
./extract-md-changes.sh f4a7b2c

# 3. Apply the cumulative changes to target repository
./apply-md-changes.sh f4a7b2c

# 4. Push changes to target repository (if desired)
cd ../dexie-web-mui
git push
```

## Advanced Usage

### Extracting Changes from Specific Ranges

The script extracts from your specified commit to HEAD. If you want a different range:

```bash
# First, checkout or reset to your desired end commit
git checkout <end-commit>

# Then extract from start to that point (now HEAD)
./extract-md-changes.sh <start-commit>
```

## Error Handling

The scripts handle various error conditions:

- **Invalid commit hash**: Verifies commit exists before processing
- **Missing target repository**: Checks for `../dexie-web-mui/` directory
- **Missing patches**: Validates that extraction was run before application
- **Patch failures**: Reports which files couldn't be applied and why

## File Structure

```
dexie-website/
├── extract-md-changes.sh      # Extraction script
├── apply-md-changes.sh        # Application script
├── diffs/                     # Generated patches directory
│   ├── abc123d_to_HEAD_docs_API.patch
│   ├── abc123d_to_HEAD_cloud_quickstart.patch
│   └── abc123d_to_HEAD_manifest.json
└── README-md-sync.md          # This documentation
```

## Troubleshooting

### "Target repository not found"

Ensure `dexie-web-mui` is cloned at the same level as `dexie-website`:

```bash
cd ..
git clone https://github.com/dexie/dexie-web-mui.git
```

### "Patch failed to apply"

This usually means the target file has diverged significantly. You can:

1. Check the failed patch manually
2. Apply changes manually in the target repository
3. Use `git apply --reject` to see specific conflicts

### "No MD files changed"

The specified commit range doesn't contain any MD file changes. Verify with:

```bash
git diff --name-only <start-commit> HEAD | grep '\.md$'
```
