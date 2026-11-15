# Protecting generated output during builds

Zeta generates the complete site in a temporary staging directory before publishing
it to `sites/<site>/public/` (or the configured `build.output_dir`).

## Customize the source, not the generated output

Permanent CSS belongs in `sites/<site>/styles/`. Images, fonts and other static
assets belong in `sites/<site>/assets/`. During each build, shared styles are copied
first, theme styles second and site-specific styles last, with site files taking
precedence for the same relative path.

A direct edit under `public/` is **not** a permanent theme override.

## How the safety check works

After each successful build, Zeta saves `.zeta-build-manifest.tsv` in the site's
root directory, **outside** the published output. It records a SHA-256 for every
generated file (and link targets for symbolic links). Before a subsequent build
replaces `public/`, Zeta compares the previous manifest to the **current** directory.
This detects edited, added and removed files without treating ordinary Markdown
source changes as manual modifications.

- If output matches its baseline, the build runs unattended.
- If output differs, an interactive terminal asks whether to discard local edits.
  The default response is **No**.
- In a non-interactive terminal/CI, replacement is blocked by default.
- To discard manual output changes intentionally, run:
  - Bash: `./zeta.sh --force build my-site`
  - PowerShell: `.\zeta.ps1 build my-site -Force`
- Pre-existing nonempty output with no baseline is treated as **unverified** and
  requires the same approval before its first guarded rebuild.
- Canceling the prompt leaves the current `public/` unchanged; the staged output
  is removed.

The manifest belongs next to site sources and is not published. A clean command
or manual removal of `public/` also removes the prior files, so the next build
starts fresh; retain a separate backup of hand-edited output if needed.

The guard is a **data-loss safeguard**, not a merge strategy. It never silently
combines old HTML or CSS with the new output because doing so could leave stale
assets or inconsistent links. Use site-level source overrides for lasting changes.
