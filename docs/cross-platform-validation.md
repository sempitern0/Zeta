# Cross-platform Zeta validation

Both entrypoints share a common publishing contract: `zeta.sh` (Bash) and `zeta.ps1` (PowerShell 7+). The old `main.sh` remains a compatibility wrapper. Bash modules live under `lib/bash/`; PowerShell modules under `lib/powershell/`.

PowerShell now includes a colored interactive workspace and management menu, detailed read-only `doctor` checks, and the aliases `new`, `appearance`, `diagnose`, `check-site`, `index`, `rm`.

## Local checks (no GitHub Actions)

```bash
make syntax
bash ./zeta.sh help
bash ./main.sh help
```

```powershell
pwsh -NoProfile -File ./zeta.ps1 help
pwsh -NoProfile -File ./zeta.ps1 sites
pwsh -NoProfile -File ./zeta.ps1 doctor MY_SITE
```

Build and inspect an identical fixture on each operating system to compare generated pages, links, sitemap and diagnostics. PowerShell runtime execution was not available in the authoring environment, so the Windows tests must be performed locally before treating the engines as fully equivalent. No GitHub Actions were run.
