# Zeta on Windows · PowerShell 7+

[← Project overview](../README.md) · [Local validation](cross-platform-validation.md)

Zeta works on Windows **without Bash, WSL, Node.js, Python, Docker or third-party PowerShell modules**. Both assistants read the same site sources under `sites/` and themes under `templates/`.

## Installation

1. Install [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
2. Clone Zeta and open PowerShell 7 in the repository root.
3. Check dependencies and open the interactive assistant:

~~~powershell
.\zeta.ps1 deps
.\zeta.ps1
~~~

Pandoc is **required for HTML builds, not for creating or editing sites**. Zeta supports an optional guided installation using Windows Package Manager (package `JohnMacFarlane.Pandoc`):

~~~powershell
.\zeta.ps1 install-pandoc       # Asks for confirmation
.\zeta.ps1 install-pandoc -Yes  # Explicit unattended installation
~~~

When `winget` is unavailable, use the [official Pandoc installer](https://pandoc.org/installing.html). Reopen PowerShell if `pandoc --version` is not found immediately.

If Windows execution policy prevents scripts from running, follow your organization's policy. Where allowed, you can invoke `pwsh -NoProfile -File .\zeta.ps1 help`; Zeta does not require an execution-policy bypass.

## Daily workflow

~~~powershell
.\zeta.ps1 create
.\zeta.ps1 sites
.\zeta.ps1 new-post my-site
.\zeta.ps1 theme my-site paper zenburn
.\zeta.ps1 build my-site
.\zeta.ps1 doctor my-site
.\zeta.ps1 preview my-site -Port 8000
.\zeta.ps1 serve
~~~

The creation wizard asks for **title, description, author, language, slug, production URL, theme and Pandoc highlighting style**. Site configuration and Markdown sources are compatible with the Bash assistant.

The common command list is maintained in the [README](../README.md#shared-commands). PowerShell uses `-Port` and `-Force` rather than Bash's `--port` and `--force`.

## Local preview and troubleshooting

- Open `http://localhost:8000/` after `preview` or `serve` (unless you selected another port).
- Stop the server with **Ctrl+C**. In compatible console hosts, press **Q** without Enter.
- If the port is busy, use `-Port 8099`.
- If generation fails, check `.\zeta.ps1 deps` and `pandoc --version`.
- Theme templates are loaded from `templates/<theme>/` using verified absolute paths. Check `theme.name` in `config.yaml` if a template is missing.

Only the generated site's `public/` directory should be deployed.

## Shared workspace and starter articles

PowerShell and Bash use the same `templates/common/workspace/` HTML and CSS to generate `sites/index.html`. Cards show status, description, theme and article counts, with a preview link for built sites and clear diagnostics for invalid configurations.

Site creation on either shell copies two Markdown demonstrations from `templates/common/examples/`; the articles exercise rich Markdown formatting and multi-language fenced code blocks. Updating those shared files updates both assistants.

## Local checks

~~~powershell
.\tests\powershell-create-smoke.ps1
.\tests\powershell-workspace-smoke.ps1   # Wizard, no Pandoc required
.\tests\powershell-build-smoke.ps1    # All eight themes; Pandoc required
.\tests\powershell-server-smoke.ps1   # Local HTTP server
~~~

These tests use temporary workspaces. They do **not** require GitHub Actions. See [cross-platform validation](cross-platform-validation.md).
