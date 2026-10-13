# Zeta terminal assistant

[← Project overview](../README.md)

Zeta offers two native command-line assistants: **`zeta.sh`** for Bash 4.3+ (Linux/macOS), and **`zeta.ps1`** for PowerShell 7+ (Windows). The former `main.sh` remains as a backwards-compatible Bash wrapper.

Both preserve the colorful ZETA wordmark, an overview of available sites and numbered options grouped by purpose.

## Navigate

The home menu groups **Workspace** (list, create and manage sites) and **Build & preview** (build, preview and serve). **Manage site** offers editing, article creation, appearance changes, diagnostics and maintenance. The Windows menu also offers Pandoc installation.

All operations can also be invoked directly without the menu:

~~~bash
./zeta.sh sites
./zeta.sh build my-site
./zeta.sh doctor my-site
~~~

~~~powershell
.\zeta.ps1 sites
.\zeta.ps1 build my-site
.\zeta.ps1 doctor my-site
~~~

## Terminal behavior

- Menus are number-driven, while command mode is suitable for scripts.
- The Bash interface supports `NO_COLOR=1` and compact output for narrower terminals. PowerShell uses native console colors and a compact banner on narrow screens.
- Bash's preview requires optional Python 3; PowerShell uses its built-in .NET server.
- Stop the PowerShell HTTP server with **Ctrl+C**, or **Q** where supported.
- Existing `./main.sh` commands still work through the compatibility wrapper.

See [Windows setup](powershell.md) and the [shared commands](../README.md#shared-commands).
