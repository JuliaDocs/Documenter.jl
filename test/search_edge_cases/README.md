# Search Edge Case Test Suite

This directory contains a dedicated test suite for Documenter.jl's search functionality.
The purpose of this suite is to provide a controlled environment for testing edge cases
that may not be present in the main documentation.

## Adding New Test Cases

To add a new test case, create a new `.md` file in the `src/` directory. Then, add
the file to the `pages` array in `make.jl`.
