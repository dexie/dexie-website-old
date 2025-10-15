#!/bin/bash

# Script to extract MD file changes from a specific commit and generate diff files
# Usage: ./extract-md-changes.sh <commit-hash>

set -e

# Check if commit hash is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <commit-hash>"
    echo "Example: $0 abc123def"
    exit 1
fi

COMMIT_HASH="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFFS_DIR="$SCRIPT_DIR/md-diffs"

echo "Extracting MD file changes for commit: $COMMIT_HASH"

# Verify the commit exists
if ! git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1; then
    echo "Error: Commit $COMMIT_HASH does not exist"
    exit 1
fi

# Create diffs directory
mkdir -p "$DIFFS_DIR"

# Clean up any existing diff files for this commit
rm -f "$DIFFS_DIR"/${COMMIT_HASH}_*.patch

# Get all MD files that were changed, added, or deleted in this commit
CHANGED_FILES=$(git diff --name-only "${COMMIT_HASH}^" "$COMMIT_HASH" | grep '\.md$' || true)

if [ -z "$CHANGED_FILES" ]; then
    echo "No MD files were changed in commit $COMMIT_HASH"
    exit 0
fi

echo "Found changed MD files:"
echo "$CHANGED_FILES"

# Counter for generated patches
patch_count=0

# Process each changed file
while IFS= read -r file; do
    if [ -n "$file" ]; then
        echo "Processing: $file"
        
        # Create safe filename for patch (replace / with _)
        safe_filename="${file//\//_}"
        patch_file="$DIFFS_DIR/${COMMIT_HASH}_${safe_filename}.patch"
        
        # Check if file was deleted
        if ! git cat-file -e "${COMMIT_HASH}:${file}" 2>/dev/null; then
            echo "  File was deleted, creating deletion patch"
            # Create a patch that shows the file deletion
            git show "$COMMIT_HASH" -- "$file" > "$patch_file"
        # Check if file was added
        elif ! git cat-file -e "${COMMIT_HASH}^:${file}" 2>/dev/null; then
            echo "  File was added, creating addition patch"
            # Create a patch that shows the file addition
            git show "$COMMIT_HASH" -- "$file" > "$patch_file"
        else
            echo "  File was modified, creating modification patch"
            # Create a patch for the modification
            git diff "${COMMIT_HASH}^" "$COMMIT_HASH" -- "$file" > "$patch_file"
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

# Create a manifest file with commit info and file list
manifest_file="$DIFFS_DIR/${COMMIT_HASH}_manifest.json"
commit_message=$(git log --format=%s -n 1 "$COMMIT_HASH")
commit_author=$(git log --format="%an <%ae>" -n 1 "$COMMIT_HASH")
commit_date=$(git log --format=%ci -n 1 "$COMMIT_HASH")

cat > "$manifest_file" << EOF
{
  "commit_hash": "$COMMIT_HASH",
  "commit_message": "$commit_message",
  "commit_author": "$commit_author",
  "commit_date": "$commit_date",
  "patch_count": $patch_count,
  "changed_files": [
$(echo "$CHANGED_FILES" | sed 's/^/    "/' | sed 's/$/"/' | sed '$!s/$/,/')
  ]
}
EOF

echo ""
echo "=== SUMMARY ==="
echo "Commit: $COMMIT_HASH"
echo "Message: $commit_message"
echo "Generated patches: $patch_count"
echo "Manifest file: $manifest_file"
echo ""
echo "Files are ready in: $DIFFS_DIR"
echo "Use ./apply-md-changes.sh $COMMIT_HASH to apply these changes"