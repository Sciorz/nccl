#!/bin/bash

# This script runs clang-format and clang-tidy on git modified lines to check for style
# and static analysis issues. It's a convenient way to ensure code quality.
# Usage: ./run-linter.sh [target-branch]
# Example: ./run-linter.sh origin/master
# This script performs line-level checking similar to git-clang-format --staged

set -e # Exit immediately if a command exits with a non-zero status.

PROJECT_ROOT=$(git rev-parse --show-toplevel)
TARGET_BRANCH="${1:-origin/master}" # Default to origin/master, or use command-line arg

# --- Helper Functions ---
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# --- Function to get modified line ranges ---
get_modified_lines() {
    local target_branch="$1"
    local file="$2"
    git diff -U0 "$target_branch" -- "$file" | grep '^@@' | sed 's/^@@.*+\([0-9,]*\).*@@.*/\1/'
}

# --- Find changed files ---
echo_green "Finding changed files between HEAD and $TARGET_BRANCH..."

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMRTUXB "$TARGET_BRANCH" -- "*.cpp" "*.hpp" "*.cu" "*.cuh" "*.c" "*.h" "*.cc" "*.cxx" "*.hh" "*.hxx")

if [[ -z "$CHANGED_FILES" ]]; then
    echo_green "No changed C++/CUDA files to lint. Exiting."
    exit 0
fi

echo "Files to be checked:"
echo "$CHANGED_FILES"

# --- Prerequisite Check ---
command -v git-clang-format >/dev/null 2>&1 || { echo_red "Error: git-clang-format is not installed. Aborting."; exit 1; }
command -v clang-format >/dev/null 2>&1 || { echo_red "Error: clang-format is not installed. Aborting."; exit 1; }
command -v clang-tidy >/dev/null 2>&1 || { echo_red "Error: clang-tidy is not installed. Aborting."; exit 1; }

# --- Step 1: Run git-clang-format to check modified lines ---
echo_green "Running git-clang-format to check modified lines..."

# Store original files checksums
declare -A before_checksums
for file in $CHANGED_FILES; do
    if [ -f "$file" ]; then
        before_checksums["$file"]=$(md5sum "$file" | cut -d' ' -f1)
    fi
done

# Run git-clang-format on the target branch comparison
git-clang-format --diff "$TARGET_BRANCH" > /tmp/clang_format_diff.txt

# Check if there are any formatting issues
if [ -s /tmp/clang_format_diff.txt ]; then
    echo_red "git-clang-format found formatting issues:"
    cat /tmp/clang_format_diff.txt
    echo_red "Please run 'git-clang-format --diff $TARGET_BRANCH | patch -p0' to fix them."
    FORMAT_ISSUES="true"
else
    echo_green "No formatting issues found in modified lines."
    FORMAT_ISSUES=""
fi

# Exit if formatting issues found
if [[ -n "$FORMAT_ISSUES" ]]; then
    exit 1
fi

# --- Step 2: Run clang-tidy on modified lines ---
# This step requires a compile_commands.json file in the build directory.

BUILD_DIR="$PROJECT_ROOT/build"
COMPILE_COMMANDS="$BUILD_DIR/compile_commands.json"

if [ ! -f "$COMPILE_COMMANDS" ]; then
    echo_red "Error: compile_commands.json not found in $BUILD_DIR"
    echo "Please generate it with your build system (e.g., cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..)"
    exit 1
fi

echo_green "Running clang-tidy on modified lines... (This may take a while)"

# Filter changed files to only include source files (.cpp and .cu)
SOURCE_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(cpp|cu|c|cc|cxx)$' || true)

if [[ -z "$SOURCE_FILES" ]]; then
    echo_green "No changed source files to analyze with clang-tidy."
else
    # Create temporary file to store filtered results
    TIDY_FILTERED_OUTPUT="/tmp/clang_tidy_filtered.txt"
    > "$TIDY_FILTERED_OUTPUT"
    
    # Process each source file
    for file in $SOURCE_FILES; do
        echo_green "Analyzing modified lines in $file..."
        
        # Get modified line ranges for this file
        MODIFIED_LINES=$(get_modified_lines "$TARGET_BRANCH" "$file")
        
        if [[ -n "$MODIFIED_LINES" ]]; then
            # Run clang-tidy on the file
            TIDY_OUTPUT=$(clang-tidy -p "$BUILD_DIR" "$file" 2>&1 || true)
            
            # Parse modified lines into an array of line numbers
            IFS=',' read -ra LINE_RANGES <<< "$MODIFIED_LINES"
            declare -A modified_line_set
            
            for range in "${LINE_RANGES[@]}"; do
                if [[ "$range" =~ ^([0-9]+)$ ]]; then
                    # Single line
                    modified_line_set[$range]=1
                elif [[ "$range" =~ ^([0-9]+),([0-9]+)$ ]]; then
                    # Range of lines
                    start=${BASH_REMATCH[1]}
                    count=${BASH_REMATCH[2]}
                    for ((i=start; i<start+count; i++)); do
                        modified_line_set[$i]=1
                    done
                fi
            done
            
            # Filter clang-tidy output to only include modified lines
            include_next_context=false
            while IFS= read -r line; do
                if [[ "$line" =~ ^([^:]+):([0-9]+):[0-9]+: ]]; then
                    file_path="${BASH_REMATCH[1]}"
                    line_num="${BASH_REMATCH[2]}"
                    # Check if this line number is in our modified lines
                    if [[ -n "${modified_line_set[$line_num]}" ]]; then
                        echo "$line" >> "$TIDY_FILTERED_OUTPUT"
                        include_next_context=true
                    else
                        include_next_context=false
                    fi
                elif [[ "$line" =~ ^[[:space:]] ]] && [[ "$include_next_context" == "true" ]]; then
                    # This is a continuation line (context), include it only if the previous issue line was included
                    echo "$line" >> "$TIDY_FILTERED_OUTPUT"
                fi
            done <<< "$TIDY_OUTPUT"
        fi
    done
    
    # Check if there are any issues found
    if [ -s "$TIDY_FILTERED_OUTPUT" ]; then
        echo_red "Clang-tidy found issues in modified lines:"
        cat "$TIDY_FILTERED_OUTPUT"
        rm -f "$TIDY_FILTERED_OUTPUT"
        exit 1
    else
        echo_green "No static analysis issues found in modified lines."
        rm -f "$TIDY_FILTERED_OUTPUT"
    fi
fi

# Clean up temporary files
rm -f /tmp/clang_format_diff.txt

echo_green "All line-level checks passed successfully!"
