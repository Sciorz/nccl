#!/bin/bash

# This script automatically fixes formatting and static analysis issues that can be
# handled safely by clang-format and clang-tidy.

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

# --- Step 1: Run clang-format to automatically fix formatting ---
echo_green "Running clang-format to fix formatting issues..."

# Find all relevant files and apply formatting in-place
find $SRC_DIRS -type f \( -name "*.cpp" -o -name "*.hpp" -o -name "*.cu" -o -name "*.cuh" \) -print0 | xargs -0 clang-format -i

echo_green "Formatting applied successfully."

# --- Step 2: Run clang-tidy to automatically fix static analysis issues ---
# This step requires a compile_commands.json file in the build directory.

BUILD_DIR="$PROJECT_ROOT/build"
COMPILE_COMMANDS="$BUILD_DIR/compile_commands.json"

if [ ! -f "$COMPILE_COMMANDS" ]; then
    echo_red "Error: compile_commands.json not found in $BUILD_DIR"
    echo "Please generate it with your build system (e.g., cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..)"
    exit 1
fi

echo_green "Running clang-tidy to apply automatic fixes... (This may take a while)"

# Find all relevant source files
SOURCE_FILES=$(find $SRC_DIRS -type f \( -name "*.cpp" -o -name "*.cu" \))

# Run clang-tidy with the -fix flag
clang-tidy -p $BUILD_DIR -fix $SOURCE_FILES

echo_green "Clang-tidy automatic fixes applied."
echo "Please review the changes (e.g., with 'git diff'). Some issues may still require manual fixing."
