# GitHub Actions CI/CD

This directory contains the GitHub Actions workflow configurations for automated testing and quality checks.

## Workflow: `ci.yml`

The main CI workflow runs on every push and pull request to `main`, `master`, or `develop` branches.

### Jobs

#### 1. **Format Check** (`format`)
- Verifies that all code follows Elixir formatting standards
- Runs: `mix format --check-formatted`
- Fails if any files need reformatting

#### 2. **Credo Strict Analysis** (`credo`)
- Performs static code analysis with strict rules
- Runs: `mix credo --strict`
- Checks for:
  - Code readability issues
  - Design suggestions
  - Refactoring opportunities
  - Code consistency
  - Warning flags

#### 3. **Tests & Coverage** (`test`)
- Runs the full test suite with coverage reporting
- Compiles with `--warnings-as-errors` to catch all warnings
- Generates coverage reports in JSON format
- Uploads coverage to Codecov (if `CODECOV_TOKEN` secret is configured)
- Creates a coverage summary in the GitHub Actions UI
- **Matrix Strategy**: Can be expanded to test multiple Elixir/OTP versions

#### 4. **Quality Gate** (`quality`)
- Final gate that checks all previous jobs passed
- Fails the build if any check failed
- Only runs after all other jobs complete

#### 5. **Coverage Report** (`coverage-report`) - Optional
- Generates detailed HTML coverage report
- Only runs on pushes to `main` branch
- Uploads coverage artifacts (available for 30 days)
- Can be downloaded from GitHub Actions artifacts

## Configuration

### Required Secrets

None required for basic functionality. Optional:

- `CODECOV_TOKEN` - For uploading coverage to Codecov (recommended)

### Customization

#### Change Elixir/OTP Versions

Edit the environment variables at the top of `ci.yml`:

```yaml
env:
  ELIXIR_VERSION: "1.19.0"
  OTP_VERSION: "27.2"
```

#### Test Multiple Versions

Expand the matrix in the `test` job:

```yaml
strategy:
  matrix:
    elixir: ["1.19.0", "1.18.0"]
    otp: ["27.2", "26.2"]
```

#### Disable Optional Jobs

Comment out or remove the `coverage-report` job if not needed.

#### Change Branch Triggers

Modify the `on` section:

```yaml
on:
  push:
    branches: [ main, develop ]  # Add/remove branches
  pull_request:
    branches: [ main ]
```

## Local Testing

Before pushing, you can run these checks locally:

```bash
# Format check
mix format --check-formatted

# Fix formatting
mix format

# Credo strict
mix credo --strict

# Tests with coverage
mix coveralls

# HTML coverage report
mix coveralls.html
# Open cover/excoveralls.html in browser

# All checks
mix format --check-formatted && mix credo --strict && mix test
```

## Coverage Reports

### Viewing Coverage Locally

```bash
mix coveralls.html
open cover/excoveralls.html  # macOS
xdg-open cover/excoveralls.html  # Linux
```

### Coverage on GitHub

- View in Actions summary after each test run
- Download HTML reports from Actions artifacts (main branch only)
- View on Codecov if token is configured

## Troubleshooting

### Cache Issues

If you encounter dependency issues, clear the cache:
1. Go to Actions → Caches
2. Delete relevant caches
3. Re-run the workflow

### Coverage Upload Fails

If Codecov upload fails:
- Verify `CODECOV_TOKEN` secret is set
- Check that the repository is added to Codecov
- The workflow won't fail if upload fails (`fail_ci_if_error: false`)

### Format Check Fails

Run locally:
```bash
mix format
git add .
git commit -m "Format code"
```

### Credo Issues

Fix issues or suppress specific checks:
```bash
# View detailed issues
mix credo --strict

# Explain specific issue
mix credo explain <filename>:<line>
```

## Best Practices

1. **Always run checks locally** before pushing
2. **Keep dependencies updated** to avoid security issues
3. **Monitor coverage trends** - aim for >80%
4. **Fix credo issues** promptly to maintain code quality
5. **Use the quality gate** to ensure all checks pass

## Performance

- **Caching** is enabled for dependencies and builds
- First run: ~2-3 minutes
- Subsequent runs: ~1-2 minutes (with warm cache)
- All jobs run in parallel except `quality` and `coverage-report`
