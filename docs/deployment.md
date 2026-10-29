# Deploying Zeta sites

Zeta publishes only the compiled output directory (`build.output_dir`, normally `sites/<site>/public/`). Markdown sources, site configuration and secrets stay local.

## Deployment center and standalone commands

The assistant is a **control panel**, not the deploy command. Run `./zeta.sh` or `.\\zeta.ps1` and select **Deployment center** to configure a provider, publish, inspect status or run a dry run. From the site management menu you can open the same panel.

The `deploy SITE` command always publishes and **never silently starts the setup wizard**. If there is no saved destination it reports the missing configuration. Both platforms also support `deploy assistant SITE` to open the panel directly. Standalone configuration remains available through `deploy setup SITE`.

## Multiple deployment providers

A site can use **GitHub Pages and Cloudflare Pages simultaneously**. Re-run `deploy setup SITE` to add or edit one provider without replacing the other. Zeta stores separate non-secret files:

```text
sites/my-site/
  deploy.conf                  # existing single-provider config, still recognized
  deploy/
    github-pages.conf          # optional
    cloudflare-pages.conf      # optional
```

No migration is necessary for an existing `deploy.conf`. A new provider file takes precedence over a legacy config for the same provider.

`deploy SITE` builds the site **once**, runs Doctor **once**, then publishes the same verified output to the selected providers. With two configured providers, the interactive assistant asks which targets to use (default: **all**) and confirms before publishing. You can choose one or both. In a non-interactive shell with multiple providers, you **must** choose explicitly; a bare `deploy SITE` fails without remote changes.

Examples:

```powershell
.\zeta.ps1 deploy triangulo-digital all
.\zeta.ps1 deploy triangulo-digital github-pages
.\zeta.ps1 deploy triangulo-digital cloudflare-pages
.\zeta.ps1 deploy dry-run triangulo-digital all
```

```bash
./zeta.sh deploy triangulo-digital all
./zeta.sh deploy triangulo-digital github-pages
./zeta.sh deploy triangulo-digital cloudflare-pages
./zeta.sh deploy --dry-run triangulo-digital all
```

For the interactive selection prompt, type `all`, `1`, `2`, or `1,2`. If one provider fails, Zeta still attempts the other and prints a per-run summary. The overall command exits unsuccessfully when any selected provider fails. Previously successful uploads are **not rolled back**.

## First publication

From an interactive terminal:

- Bash: `./zeta.sh deploy setup my-site`
- PowerShell: `.\\zeta.ps1 deploy setup my-site`

Setup configures the destination but never publishes. The wizard asks for GitHub Pages or Cloudflare Pages, and saves the non-secret destination settings in the site's `deploy.conf` (ignored by the Zeta repository because `sites/*` is ignored).

### GitHub Pages

Create a GitHub repository with an existing `gh-pages` branch. In repository **Settings → Pages**, set **Deploy from a branch**, select **gh-pages**, and folder **/(root)**. Zeta uses your existing Git authentication to clone that branch, replace its tracked content with the generated site, commit changes and push. This is a **dedicated publishing branch**: do not store unrelated files or hand-authored content there; tracked files not in the build output are deleted. The remote repository itself is never deleted. Zeta adds `.nojekyll`.

### Cloudflare Pages

Create a Cloudflare Pages project for Direct Upload, install Wrangler and authenticate with `wrangler login`. The wizard saves the project name and optional account ID; it never saves API tokens. Zeta publishes with `wrangler pages deploy <output> --project-name <project>`.

## Subsequent updates

- Bash: `./zeta.sh deploy my-site`
- PowerShell: `.\\zeta.ps1 deploy my-site`

The deploy command builds and checks with Doctor before publishing. Run `deploy setup SITE` to add or change a provider without publishing. Interactive publishing asks for confirmation. Run `deploy status <site>` to inspect the destination or `deploy --dry-run <site>` (Bash) / `deploy dry-run <site>` (PowerShell) to list existing build artifacts without contacting the provider or changing the remote site.

Review the site's `site.url` before publication: GitHub Pages project sites need the repository subpath, for example `https://username.github.io/project/`. Zeta does not automatically enable Pages settings or create remote Cloudflare projects. The configured publishing repository or Pages project must already exist.

Credentials are delegated to Git Credential Manager, GitHub CLI, or Wrangler. Keep `deploy.conf` private if it contains internal repository or account identifiers; it contains no passwords.
