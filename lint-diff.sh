#!/bin/bash

# This script lints only the files that have changed compared to a target branch.
# Usage: ./lint-diff.sh <target-branch>
# Example: ./lint-diff.sh upstream/main

set -e

TARGET_BRANCH="${1:-upstream/main}"

# --- Helper Functions ---
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# --- Find changed files ---
echo_green "Finding changed files between HEAD and $TARGET_BRANCH..."

CHANGED_FILES=$(git diff --name-only --diff-filter=ACMRTUXB "$TARGET_BRANCH" -- "*.cpp" "*.hpp" "*.cu" "*.cuh")

if [[ -z "$CHANGED_FILES" ]]; then
    echo_green "No changed C++/CUDA files to lint. Exiting."
    exit 0
fi

echo "Files to be checked:"
echo "$CHANGED_FILES"

# --- Prerequisite Check ---
# (Assuming clang-format, clang-tidy, and compile_commands.json are available)

# --- Run Linters ---
echo_green "
Running clang-format check..."
clang-format --dry-run -Werror $CHANGED_FILES

echo_green "
Running clang-tidy check..."
clang-tidy -p build/ $CHANGED_FILES

echo_green "
All checks passed on changed files!"
