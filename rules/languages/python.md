### Python Best Practices

#### Code Style
- Follow PEP 8 style guide
- Use type hints for function signatures
- Look for and use justfile or Makefile helpers when doing linting and formatting
- If none exist Use `black` for formatting, `ruff` or `flake8` for linting
- Prefer `pathlib.Path` over `os.path` for path operations
- Use context managers (`with`) for file operations

#### Error Handling
```python
# GOOD: Specific exceptions with context
def read_config(path: Path) -> dict:
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        raise ConfigError(f"Config file not found: {path}")
    except json.JSONDecodeError as e:
        raise ConfigError(f"Invalid JSON in {path}: {e}")

# BAD: Bare except or swallowing errors
def read_config(path):
    try:
        return json.load(open(path))
    except:  # Don't do this
        return {}
```

#### Security
- Never use `eval()` or `exec()` on user input
- Use `subprocess.run()` with explicit args, never `shell=True` with user input
- Use parameterized queries for SQL (never f-strings)
- Validate and sanitize all external input

#### Dependencies
- prefer using `pyproject.toml` to manage dependencies and keep application repo
  dependencies tight but not exact.
- Run `pip-audit` to check for vulnerabilities

#### Testing
- look for justfile or Taskfile commands before running tests directly.
- If no helpers exist use `pytest` for testing
- Aim for high coverage with `pytest-cov`
- Mock external dependencies with `unittest.mock`
