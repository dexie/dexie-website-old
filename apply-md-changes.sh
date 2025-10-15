#!/bin/bash

# Script to apply MD file changes to dexie-web-mui repository
# Usage: ./apply-md-changes.sh <commit-hash>

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
TARGET_REPO_DIR="$SCRIPT_DIR/../dexie-web-mui"

echo "Applying MD file changes for commit: $COMMIT_HASH"

# Check if target repository exists
if [ ! -d "$TARGET_REPO_DIR" ]; then
    echo "Error: Target repository not found at $TARGET_REPO_DIR"
    echo "Please ensure dexie-web-mui is cloned at the same level as dexie-website"
    exit 1
fi

# Check if manifest file exists
manifest_file="$DIFFS_DIR/${COMMIT_HASH}_manifest.json"
if [ ! -f "$manifest_file" ]; then
    echo "Error: Manifest file not found: $manifest_file"
    echo "Please run ./extract-md-changes.sh $COMMIT_HASH first"
    exit 1
fi

# Read manifest information
if command -v jq >/dev/null 2>&1; then
    commit_message=$(jq -r '.commit_message' "$manifest_file")
    patch_count=$(jq -r '.patch_count' "$manifest_file")
    commit_author=$(jq -r '.commit_author' "$manifest_file")
    commit_date=$(jq -r '.commit_date' "$manifest_file")
else
    # Fallback parsing without jq
    commit_message=$(grep '"commit_message"' "$manifest_file" | cut -d'"' -f4)
    patch_count=$(grep '"patch_count"' "$manifest_file" | cut -d':' -f2 | tr -d ' ,')
    commit_author=$(grep '"commit_author"' "$manifest_file" | cut -d'"' -f4)
    commit_date=$(grep '"commit_date"' "$manifest_file" | cut -d'"' -f4)
fi

echo "Commit: $COMMIT_HASH"
echo "Message: $commit_message"
echo "Patches to apply: $patch_count"
echo "Target directory: $TARGET_REPO_DIR"
echo ""

# Change to target repository
cd "$TARGET_REPO_DIR"

# Configure git if not already configured
if [ -z "$(git config user.name)" ]; then
    git config user.name "MD Sync Script"
    git config user.email "sync@example.com"
fi

# Arrays to track results
APPLIED_PATCHES=()
FAILED_PATCHES=()
DELETED_FILES=()
ADDED_FILES=()

# Find all patch files for this commit
for patch_file in "$DIFFS_DIR/${COMMIT_HASH}_"*.patch; do
    if [ -f "$patch_file" ]; then
        # Extract original filename from patch filename
        base_patch_name=$(basename "$patch_file")
        # Remove commit hash and .patch extension, then convert _ back to /
        original_file=$(echo "$base_patch_name" | sed "s/^${COMMIT_HASH}_//" | sed 's/\.patch$//' | tr '_' '/')
        
        echo "Processing: $original_file"
        
        # Determine the type of change by examining the patch
        if grep -q "^deleted file mode" "$patch_file"; then
            echo "  File deletion detected"
            if [ -f "$original_file" ]; then
                rm "$original_file"
                git add "$original_file"
                DELETED_FILES+=("$original_file")
                echo "  ✓ File deleted: $original_file"
            else
                echo "  ⚠ File already doesn't exist: $original_file"
            fi
        elif grep -q "^new file mode" "$patch_file"; then
            echo "  File addition detected"
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "$original_file")"
            
            if git apply --check "$patch_file" 2>/dev/null; then
                git apply "$patch_file"
                git add "$original_file"
                ADDED_FILES+=("$original_file")
                echo "  ✓ File added: $original_file"
            else
                echo "  ✗ Could not apply addition patch for: $original_file"
                FAILED_PATCHES+=("$original_file (addition)")
            fi
        else
            echo "  File modification detected"
            if [ -f "$original_file" ]; then
                # Try to apply the patch
                if git apply --check "$patch_file" 2>/dev/null; then
                    git apply "$patch_file"
                    git add "$original_file"
                    APPLIED_PATCHES+=("$original_file")
                    echo "  ✓ Patch applied: $original_file"
                else
                    echo "  ✗ Patch failed, trying 3-way merge: $original_file"
                    # Try 3-way merge
                    if git apply --3way "$patch_file" 2>/dev/null; then
                        git add "$original_file"
                        APPLIED_PATCHES+=("$original_file (3-way)")
                        echo "  ✓ 3-way merge succeeded: $original_file"
                    else
                        echo "  ✗ 3-way merge also failed: $original_file"
                        FAILED_PATCHES+=("$original_file (modification)")
                    fi
                fi
            else
                echo "  ⚠ Target file doesn't exist, treating as addition"
                mkdir -p "$(dirname "$original_file")"
                if git apply "$patch_file" 2>/dev/null; then
                    git add "$original_file"
                    ADDED_FILES+=("$original_file")
                    echo "  ✓ File created: $original_file"
                else
                    echo "  ✗ Could not create file: $original_file"
                    FAILED_PATCHES+=("$original_file (creation)")
                fi
            fi
        fi
    fi
done

# Print summary
echo ""
echo "=== SUMMARY ==="
echo "Applied patches: ${#APPLIED_PATCHES[@]}"
for file in "${APPLIED_PATCHES[@]}"; do
    echo "  ✓ $file"
done

echo "Added files: ${#ADDED_FILES[@]}"
for file in "${ADDED_FILES[@]}"; do
    echo "  + $file"
done

echo "Deleted files: ${#DELETED_FILES[@]}"
for file in "${DELETED_FILES[@]}"; do
    echo "  - $file"
done

echo "Failed patches: ${#FAILED_PATCHES[@]}"
for file in "${FAILED_PATCHES[@]}"; do
    echo "  ✗ $file"
done

# Commit changes if any were applied
total_changes=$((${#APPLIED_PATCHES[@]} + ${#ADDED_FILES[@]} + ${#DELETED_FILES[@]}))
if [ $total_changes -gt 0 ]; then
    # Create commit message
    commit_msg="Sync MD files from dexie-website

Original commit: $COMMIT_HASH
Original message: $commit_message
Original author: $commit_author
Original date: $commit_date

Changes:
- Applied patches: ${#APPLIED_PATCHES[@]}
- Added files: ${#ADDED_FILES[@]}
- Deleted files: ${#DELETED_FILES[@]}
- Failed patches: ${#FAILED_PATCHES[@]}"

    git commit -m "$commit_msg"
    echo ""
    echo "✓ Changes committed successfully!"
    echo "Commit message includes original commit information."
    
    # Show what would be pushed
    echo ""
    echo "To push changes, run: cd $TARGET_REPO_DIR && git push"
else
    echo ""
    echo "No changes to commit."
fi