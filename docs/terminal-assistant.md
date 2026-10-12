# Minimal, useful terminal interface

Zeta's terminal assistant intentionally uses **only Bash built-ins, printf, ANSI colors and Pandoc**. It avoids interactive frameworks, dependency installation and network-backed widgets.

## Workspace view

The initial screen shows the number of sites, renderer readiness, and a compact listing of up to four sites with post counts, selected theme and generated-state indicator. Actions are grouped by goal: workspace management versus build and preview.

## Site view

Select **Manage site** to see the selected site's title, slug, Markdown count, theme and build status, plus grouped commands for editing, content, validation and maintenance. Short command descriptions explain effects before running them.

## Accessibility and terminal behavior

- Input remains number-based and compatible with ordinary terminal stdin.
- Output avoids cursor control sequences and full-screen UI dependencies.
- `NO_COLOR=1` and non-interactive terminals disable ANSI output.
- The CLI keeps non-interactive script commands stable for CI.
- The assistant is intended for Linux terminals and WSL; use `zeta.ps1` natively on Windows.

```bash
./main.sh
./main.sh --help
./main.sh sites
./main.sh doctor my-site
```
