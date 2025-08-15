#!/bin/bash

# This script runs clang-format and clang-tidy on the project to check for style
# and static analysis issues. It's a convenient way to ensure code quality.

set -e # Exit immediately if a command exits with a non-zero status.

PROJECT_ROOT=$(git rev-parse --show-toplevel)
SRC_DIRS="${1:-src include tests}" # Default to src, include, tests, or use command-line arg

# --- Helper Functions ---
echo_green() {
    echo -e "\033[0;32m$1\033[0m"
}

echo_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# --- Prerequisite Check ---
command -v clang-format >/dev/null 2>&1 || { echo_red "Error: clang-format is not installed. Aborting."; exit 1; }
command -v clang-tidy >/dev/null 2>&1 || { echo_red "Error: clang-tidy is not installed. Aborting."; exit 1; }

# --- Step 1: Run clang-format to check for formatting issues ---
echo_green "Running clang-format check..."

# Find all relevant files and check them
FORMAT_ISSUES=$(find $SRC_DIRS -type f \( -name "*.cpp" -o -name "*.hpp" -o -name "*.cu" -o -name "*.cuh" \) -print0 | xargs -0 clang-format --dry-run -Werror)

if [[ -n "$FORMAT_ISSUES" ]]; then
    echo_red "Clang-format found issues in the following files:"
    echo "$FORMAT_ISSUES"
    echo_red "Please run 'clang-format -i <file>' to fix them."
    exit 1
else
    echo_green "No formatting issues found."
fi

# --- Step 2: Run clang-tidy for static analysis ---
# This step requires a compile_commands.json file in the build directory.

BUILD_DIR="$PROJECT_ROOT/build"
COMPILE_COMMANDS="$BUILD_DIR/compile_commands.json"

if [ ! -f "$COMPILE_COMMANDS" ]; then
    echo_red "Error: compile_commands.json not found in $BUILD_DIR"
    echo "Please generate it with your build system (e.g., cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..)"
    exit 1
fi

echo_green "Running clang-tidy check... (This may take a while)"

# Find all relevant files
SOURCE_FILES=$(find $SRC_DIRS -type f \( -name "*.cpp" -o -name "*.cu" \))

TIDY_ISSUES=$(clang-tidy -p $BUILD_DIR $SOURCE_FILES)

if [[ -n "$TIDY_ISSUES" ]]; then
    echo_red "Clang-tidy found issues:"
    echo "$TIDY_ISSUES"
    exit 1
else
    echo_green "No static analysis issues found."
fi

echo_green "All checks passed successfully!"
