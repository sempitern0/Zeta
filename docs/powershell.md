# Zeta on Windows: PowerShell 7+

Zeta now has two native entry points: `./main.sh` for Bash and `./zeta.ps1` for PowerShell. Both use the same `sites/<site>/config.yaml`, Markdown posts, `templates/` and generated `public/` structure. There is no need for WSL, Node.js, a PowerShell module or a runtime web framework. **Pandoc remains a required external executable for building**, just as on Linux.

## Install

1. Install [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows) and [Pandoc](https://pandoc.org/installing.html).
2. Open PowerShell in the repository root. Ensure `pandoc --version` works.
3. Run `./zeta.ps1` for the interactive assistant or `./zeta.ps1 help`.

If the machine's execution policy prevents running the script, consult your organization's policy first. For a personally managed development shell, use `pwsh -NoProfile -File ./zeta.ps1 help`; an execution policy bypass is **not** required by Zeta itself.

## Workflow

```powershell
./zeta.ps1 create
./zeta.ps1 sites
./zeta.ps1 new-post my-site
./zeta.ps1 build my-site
./zeta.ps1 doctor my-site
./zeta.ps1 preview my-site -Port 8000
```

`./zeta.ps1 theme my-site indie` and `./zeta.ps1 theme my-site organization` reuse existing themes. Edit `sites/my-site/landing.yaml` for CTA links, and `landing.md` for the mission or game introduction. For individual repository links, use an `external_url` key in the post's Markdown frontmatter. All output remains static and can be deployed to any static host.

### Supported commands

| PowerShell | Function |
|---|---|
| `./zeta.ps1` | Interactive assistant |
| `./zeta.ps1 sites` | List sites and build state |
| `./zeta.ps1 create` | Create site interactively |
| `./zeta.ps1 edit SITE` | Edit metadata |
| `./zeta.ps1 theme SITE THEME` | Change theme, rebuild |
| `./zeta.ps1 posts SITE` | List source Markdown entries |
| `./zeta.ps1 new-post SITE` | Create a Markdown scaffold |
| `./zeta.ps1 build SITE` | Build a site atomically |
| `./zeta.ps1 build-all` | Build every site |
| `./zeta.ps1 preview SITE` | Serve just one site on loopback |
| `./zeta.ps1 serve` | Serve the workspace on loopback |
| `./zeta.ps1 dashboard` | Generate the local index |
| `./zeta.ps1 doctor SITE` | Minimal readiness checks |
| `./zeta.ps1 clean SITE` | Remove output without deleting sources |
| `./zeta.ps1 delete SITE` | Delete a site after typing its name (or with `-Force`) |
| `./zeta.ps1 fonts SITE KEY` | Install optional open fonts or restore theme defaults with `remove` |

The native Windows implementation currently focuses on the core publishing workflow. Advanced Bash-specific helpers—including detailed doctor color swatches, richer post listings and the interactive site-management submenu—are not yet implemented at identical depth. PowerShell fonts use its built-in HTTP client to download optional assets and licenses; no additional module is required. Cross-platform smoke tests run on Windows and Ubuntu. The two engines operate on the same authoring format, but generated HTML should still be compared before switching production builds.

## Data safety

Builds use a staging directory and replace `public/` after Pandoc succeeds. Keep backups of `config.yaml`, `landing.yaml`, `landing.md`, `posts/` and `assets/`. Do not deploy these source files: deploy only `public/`.
