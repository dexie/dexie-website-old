# MD Files Historical Sync Scripts

These scripts allow you to extract and apply MD file changes from historical commits in the dexie-website repository to the dexie-web-mui repository.

## Prerequisites

- Both repositories should be cloned at the same directory level:
  ```
  parent-directory/
  ├── dexie-website/
  └── dexie-web-mui/
  ```
- `jq` is recommended but not required (the scripts have fallback parsing)

## Usage

### 1. Extract MD changes from a commit

```bash
./extract-md-changes.sh <commit-hash>
```

**Example:**

```bash
./extract-md-changes.sh abc123def
```

**What it does:**

- Analyzes the specified commit for MD file changes (added, modified, deleted)
- Generates `.patch` files for each changed MD file
- Creates a manifest file with commit metadata
- Stores everything in `md-diffs/` directory

**Output files:**

- `md-diffs/<commit>_<filename>.patch` - Individual patch files
- `md-diffs/<commit>_manifest.json` - Metadata about the commit

### 2. Apply changes to target repository

```bash
./apply-md-changes.sh <commit-hash>
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
- Creates a commit with detailed metadata

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

### Commit Preservation

- Preserves original commit metadata (hash, message, author, date)
- Creates descriptive commit messages in the target repository
- Links back to the original commit for traceability

## Example Workflow

```bash
# 1. Find a commit with MD changes you want to sync
git log --oneline --name-only | grep -B1 '\.md$'

# 2. Extract changes from that commit
./extract-md-changes.sh f4a7b2c

# 3. Apply changes to target repository
./apply-md-changes.sh f4a7b2c

# 4. Push changes to target repository (if desired)
cd ../dexie-web-mui
git push
```

## Batch Processing

To process multiple commits, you can use a simple loop:

```bash
# Process the last 10 commits that modified MD files
for commit in $(git log --format=%H --name-only | grep -B1 '\.md$' | grep '^[a-f0-9]' | head -10); do
  echo "Processing commit: $commit"
  ./extract-md-changes.sh "$commit"
  ./apply-md-changes.sh "$commit"
done
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
├── md-diffs/                  # Generated patches directory
│   ├── abc123_docs_API.patch
│   ├── abc123_cloud_quickstart.patch
│   └── abc123_manifest.json
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

The specified commit doesn't contain any MD file changes. Verify with:

```bash
git show --name-only <commit-hash> | grep '\.md$'
```
