#!/bin/bash
set -e -x
# Pre-commit hook script for clang-format on modified lines
# Only processes C/C++/CUDA files

# Get the list of staged files that are C/C++/CUDA files
staged_files=$(git diff --staged --name-only --diff-filter=ACM | grep -E '\.(c|cc|cpp|cxx|cu|h|hh|hpp|hxx)$')

if [ -z "$staged_files" ]; then
    echo "No C/C++/CUDA files to format"
    exit 0
fi

# Store the current state of staged files
echo "Running clang-format on modified lines..."
echo "Staged C/C++/CUDA files: $staged_files"

# Get checksums of staged files before formatting
declare -A before_checksums
for file in $staged_files; do
    if [ -f "$file" ]; then
        before_checksums["$file"]=$(md5sum "$file" | cut -d' ' -f1)
    fi
done

# Run git-clang-format only on the staged C/C++/CUDA files
which git-clang-format
git-clang-format --staged --quiet

# Check if any of the staged files were modified by clang-format
files_changed=""
for file in $staged_files; do
    if [ -f "$file" ]; then
        current_checksum=$(md5sum "$file" | cut -d' ' -f1)
        if [ "${before_checksums[$file]}" != "$current_checksum" ]; then
            files_changed="$files_changed $file"
        fi
    fi
done

if [ -n "$files_changed" ]; then
    echo "clang-format made changes to the following files:"
    echo "$files_changed"
    echo "Please review the changes and re-stage the files."
    exit 1
fi

echo "All staged files are properly formatted."
exit 0
