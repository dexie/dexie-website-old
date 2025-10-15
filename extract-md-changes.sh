#!/bin/bash

# Script to extract MD file changes from a commit range and generate diff files
# Usage: ./extract-md-changes.sh <start-commit-hash>
# Extracts all MD changes from start-commit to HEAD

set -e

# Check if commit hash is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <start-commit-hash>"
    echo "Example: $0 abc123def"
    echo "This will extract all MD changes from abc123def to HEAD"
    exit 1
fi

START_COMMIT="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFFS_DIR="$SCRIPT_DIR/diffs"

echo "Extracting MD file changes from commit: $START_COMMIT to HEAD"

# Verify the start commit exists
if ! git rev-parse --verify "$START_COMMIT" >/dev/null 2>&1; then
    echo "Error: Commit $START_COMMIT does not exist"
    exit 1
fi

# Create diffs directory
mkdir -p "$DIFFS_DIR"

# Clean up any existing diff files for this range
RANGE_NAME="${START_COMMIT:0:7}_to_HEAD"
rm -f "$DIFFS_DIR"/${RANGE_NAME}_*.patch

# Get all MD files that were changed, added, or deleted in the commit range
CHANGED_FILES=$(git diff --name-only "$START_COMMIT" HEAD | grep '\.md$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No MD files were changed between $START_COMMIT and HEAD"
    exit 0
fi

echo "Found changed MD files in range:"
echo "$CHANGED_FILES"

# Get HEAD commit hash for reference
HEAD_COMMIT=$(git rev-parse HEAD)
echo "Commit range: $START_COMMIT...$HEAD_COMMIT"

# Counter for generated patches
patch_count=0

# Process each changed file
while IFS= read -r file; do
    if [ -n "$file" ]; then
        echo "Processing: $file"
        
        # Create safe filename for patch (replace / with _)
        safe_filename="${file//\//_}"
        patch_file="$DIFFS_DIR/${RANGE_NAME}_${safe_filename}.patch"
        
        # Check if file exists at HEAD but not at start commit
        if git cat-file -e "HEAD:${file}" 2>/dev/null && ! git cat-file -e "${START_COMMIT}:${file}" 2>/dev/null; then
            echo "  File was added in range, creating addition patch"
            # Create a patch that shows the file addition
            git diff --no-index /dev/null "$file" > "$patch_file" || true
        # Check if file exists at start commit but not at HEAD  
        elif ! git cat-file -e "HEAD:${file}" 2>/dev/null && git cat-file -e "${START_COMMIT}:${file}" 2>/dev/null; then
            echo "  File was deleted in range, creating deletion patch"
            # Create a patch that shows the file deletion
            git diff --no-index "$START_COMMIT:$file" /dev/null > "$patch_file" || true
        else
            echo "  File was modified in range, creating modification patch"
            # Create a patch for the modification from start to HEAD
            git diff "$START_COMMIT" HEAD -- "$file" > "$patch_file"
        fi
        
        # Check if patch file has content
        if [ -s "$patch_file" ]; then
            echo "  ✓ Generated patch: $patch_file"
            ((patch_count++))
        else
            echo "  ✗ Empty patch generated, removing file"
            rm -f "$patch_file"
        fi
    fi
done <<< "$CHANGED_FILES"

# Create a manifest file with commit range info and file list
manifest_file="$DIFFS_DIR/${RANGE_NAME}_manifest.json"
start_commit_message=$(git log --format=%s -n 1 "$START_COMMIT")
head_commit_message=$(git log --format=%s -n 1 "HEAD")
commit_count=$(git rev-list --count "${START_COMMIT}..HEAD")

cat > "$manifest_file" << EOF
{
  "start_commit": "$START_COMMIT",
  "head_commit": "$HEAD_COMMIT",
  "start_commit_message": "$start_commit_message",
  "head_commit_message": "$head_commit_message",
  "commit_count": $commit_count,
  "patch_count": $patch_count,
  "range_name": "$RANGE_NAME",
  "changed_files": [
$(echo "$CHANGED_FILES" | sed 's/^/    "/' | sed 's/$/"/' | sed '$!s/$/,/')
  ]
}
EOF

echo ""
echo "=== SUMMARY ==="
echo "Commit range: $START_COMMIT to $HEAD_COMMIT"
echo "Commits in range: $commit_count"
echo "Start message: $start_commit_message"
echo "Head message: $head_commit_message"
echo "Generated patches: $patch_count"
echo "Manifest file: $manifest_file"
echo ""
echo "Files are ready in: $DIFFS_DIR"
echo "Use ./apply-md-changes.sh $START_COMMIT to apply these changes"