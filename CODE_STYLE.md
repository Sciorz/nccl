# Project Code Style and Quality Guide

This document outlines the code style guidelines and quality assurance practices for this project. Our goal is to maintain a clean, consistent, and high-quality codebase that is easy to read, maintain, and contribute to.

Our style is based on the [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html), with modifications inspired by the [RAPIDS.ai C++ and CUDA Style Guide](https://docs.rapids.ai/s-dev/style-guide/).

## Core Principles

1.  **Consistency**: Code should look like it was written by a single person.
2.  **Readability**: Code is for humans first, machines second.
3.  **Explicitness**: The intent of the code should be clear.
4.  **Modernity**: Leverage modern C++ (C++17) and CUDA features for safer, more expressive code.

## Tools

We use `clang-format` and `clang-tidy` to automate the enforcement of our code style.

-   **`clang-format`**: Handles all code formatting (indentation, spacing, line breaks). Its rules are defined in the `.clang-format` file.
-   **`clang-tidy`**: Performs static analysis to find potential bugs, performance issues, and style violations. Its rules are defined in the `.clang-tidy` file.

## How to Check Your Code

Before submitting code, you must run the linter script to ensure your changes meet our standards.

### Prerequisites

1.  **Install Tools**: Make sure you have `clang-format` and `clang-tidy` installed. On macOS, you can use Homebrew:
    ```bash
    brew install llvm
    ```

2.  **Generate `compile_commands.json`**: `clang-tidy` requires information about how the code is compiled. Our CMake build system can generate this for you. From your `build` directory, run:
    ```bash
    cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
    ```
    You only need to do this once, or whenever you add new files to the project.

### Running the Linter

Simply execute the `run-linter.sh` script from the project's root directory:

```bash
./run-linter.sh
```

The script will check all files in `src/`, `include/`, and `tests/` by default. If you want to check specific directories, you can pass them as arguments:

```bash
./run-linter.sh "src/my_feature_dir"
```

### Fixing Issues

-   **Formatting Issues**: The script will report which files have formatting problems. You can fix them automatically with:
    ```bash
    clang-format -i <path/to/file>
    ```

-   **Static Analysis Issues**: `clang-tidy` will report issues with detailed descriptions. You will need to fix these manually based on the provided diagnostics.

## Key Style Guidelines

### Naming Conventions

-   **Variables**: `snake_case` (e.g., `my_variable`).
-   **Functions/Methods**: `PascalCase` (e.g., `CalculateValue()`).
-   **Classes/Structs/Enums**: `PascalCase` (e.g., `class DataManager;`).
-   **Constants**: `k` followed by `PascalCase` (e.g., `const int kMaxIterations = 100;`).
-   **Macros**: `ALL_CAPS_SNAKE_CASE` (e.g., `#define MY_MACRO`).

### CUDA-Specific Naming

To distinguish between host and device code/data, we use prefixes:

-   `h_`: Host (CPU) memory pointers (e.g., `int* h_data;`).
-   `d_`: Device (GPU) global memory pointers (e.g., `float* d_results;`).
-   `s_`: Shared memory variables (e.g., `extern __shared__ float s_cache[];`).
-   `c_`: Constant memory variables (e.g., `__constant__ float c_coefficients[256];`).
-   **Kernels**: End with `_kernel` (e.g., `MyComputation_kernel<<<...>>>`).

### Error Handling

All CUDA API calls **must** be checked for errors. Use a macro for this purpose.

```cpp
#define CUDA_CHECK(err) { /* ... error checking logic ... */ }

CUDA_CHECK(cudaMalloc(&d_data, size));
```

### Comments

-   Use Doxygen-style comments for public APIs.
-   Comment the "why," not the "what."
