#!/bin/bash

# Script to apply all MD file changes from diffs/ directory to dexie-web-mui repository
# Usage: ./apply-md-changes.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFFS_DIR="$SCRIPT_DIR/diffs"
TARGET_REPO_DIR="$SCRIPT_DIR/../dexie-web-mui"

echo "Applying all MD file changes from diffs/ directory"

# Check if target repository exists
if [ ! -d "$TARGET_REPO_DIR" ]; then
    echo "Error: Target repository not found at $TARGET_REPO_DIR"
    echo "Please ensure dexie-web-mui is cloned at the same level as dexie-website"
    exit 1
fi

# Check if diffs directory exists
if [ ! -d "$DIFFS_DIR" ]; then
    echo "Error: Diffs directory not found at $DIFFS_DIR"
    echo "Please run ./extract-md-changes.sh <commit-hash> first"
    exit 1
fi

# Find all patch files in diffs directory
PATCH_FILES=("$DIFFS_DIR"/*.patch)
if [ ! -f "${PATCH_FILES[0]}" ]; then
    echo "No patch files found in $DIFFS_DIR"
    echo "Please run ./extract-md-changes.sh <commit-hash> first"
    exit 1
fi

# Find manifest files to get metadata (there might be multiple)
MANIFEST_FILES=("$DIFFS_DIR"/*_manifest.json)
if [ -f "${MANIFEST_FILES[0]}" ]; then
    # Use the first manifest file for metadata
    manifest_file="${MANIFEST_FILES[0]}"
    echo "Using manifest: $(basename "$manifest_file")"
    
    # Read manifest information if jq is available
    if command -v jq >/dev/null 2>&1; then
        start_commit=$(jq -r '.start_commit // "unknown"' "$manifest_file")
        head_commit=$(jq -r '.head_commit // "unknown"' "$manifest_file")
        commit_count=$(jq -r '.commit_count // 0' "$manifest_file")
        echo "Commit range: $start_commit to $head_commit"
        echo "Commits in range: $commit_count"
    fi
else
    echo "No manifest file found, proceeding with patch application"
fi

echo "Found ${#PATCH_FILES[@]} patch files to process"
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

# Find all patch files and process them
for patch_file in "${PATCH_FILES[@]}"; do
    if [ -f "$patch_file" ] && [[ "$patch_file" == *.patch ]]; then
        # Extract original filename from patch filename
        base_patch_name=$(basename "$patch_file")
        # Remove any range prefix and .patch extension, then convert _ back to /
        # Handle both old format (commit_file.patch) and new format (range_file.patch)
        if [[ "$base_patch_name" == *"_to_HEAD_"* ]]; then
            # New format: range_to_HEAD_filename.patch
            original_file=$(echo "$base_patch_name" | sed 's/^.*_to_HEAD_//' | sed 's/\.patch$//' | tr '_' '/')
        else
            # Old format or simple format: prefix_filename.patch
            original_file=$(echo "$base_patch_name" | sed 's/^[^_]*_//' | sed 's/\.patch$//' | tr '_' '/')
        fi
        
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
    # Create commit message with available information
    if [ -n "$start_commit" ] && [ -n "$head_commit" ]; then
        commit_msg="Sync MD files from dexie-website

Commit range: $start_commit to $head_commit
Commits in range: $commit_count

Changes:
- Applied patches: ${#APPLIED_PATCHES[@]}
- Added files: ${#ADDED_FILES[@]}
- Deleted files: ${#DELETED_FILES[@]}
- Failed patches: ${#FAILED_PATCHES[@]}"
    else
        commit_msg="Sync MD files from dexie-website

Applied patches from diffs/ directory

Changes:
- Applied patches: ${#APPLIED_PATCHES[@]}
- Added files: ${#ADDED_FILES[@]}
- Deleted files: ${#DELETED_FILES[@]}
- Failed patches: ${#FAILED_PATCHES[@]}"
    fi

    git commit -m "$commit_msg"
    echo ""
    echo "✓ Changes committed successfully!"
    echo "Commit message includes available metadata."
    
    # Show what would be pushed
    echo ""
    echo "To push changes, run: cd $TARGET_REPO_DIR && git push"
else
    echo ""
    echo "No changes to commit."
fi