set quiet

# List available recipes
help:
    just --unstable --list --unsorted

# Run the development server
run:
    PORT=5173 elm-land server

# Run tests once
test:
    npx vitest run

# Run tests in watch mode
test-watch:
    npx vitest

# Run tests with coverage
test-coverage:
    npx vitest run --coverage

# Run tests with UI
test-ui:
    npx vitest --ui

# Sort Tailwind classes in all files
sort:
    #!/usr/bin/env bash
    set -eu
    rustywind --write --custom-regex "\bclass[\s(<|]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s(]+\"[^\"]*\"[\s+]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclass[\s<|]+\"[^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" [^\"]*\"\s*\+{2}\s*\" ([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
    rustywind --write --custom-regex "\bclassList[\s\[\(]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"[^\"]*\",\s[^\)]+\)[\s\[\(,]+\"([^\"]*)\"" .
