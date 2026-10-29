# Deploying Zeta sites

Zeta publishes only the compiled output directory (`build.output_dir`, normally `sites/<site>/public/`). Markdown sources, site configuration and secrets stay local.

## First publication

From an interactive terminal:

- Bash: `./zeta.sh deploy setup my-site`
- PowerShell: `.\\zeta.ps1 deploy setup my-site`

The wizard asks for GitHub Pages or Cloudflare Pages, and saves the non-secret destination settings in the site's `deploy.conf` (ignored by the Zeta repository because `sites/*` is ignored).

### GitHub Pages

Create a GitHub repository with an existing `gh-pages` branch. In repository **Settings → Pages**, set **Deploy from a branch**, select **gh-pages**, and folder **/(root)**. Zeta uses your existing Git authentication to clone that branch, replace its tracked content with the generated site, commit changes and push. This is a **dedicated publishing branch**: do not store unrelated files or hand-authored content there; tracked files not in the build output are deleted. The remote repository itself is never deleted. Zeta adds `.nojekyll`.

### Cloudflare Pages

Create a Cloudflare Pages project for Direct Upload, install Wrangler and authenticate with `wrangler login`. The wizard saves the project name and optional account ID; it never saves API tokens. Zeta publishes with `wrangler pages deploy <output> --project-name <project>`.

## Subsequent updates

- Bash: `./zeta.sh deploy my-site`
- PowerShell: `.\\zeta.ps1 deploy my-site`

The deploy command builds and checks with Doctor before publishing. Interactive publishing asks for confirmation. Run `deploy status <site>` to inspect the destination or `deploy --dry-run <site>` (Bash) / `deploy dry-run <site>` (PowerShell) to list existing build artifacts without contacting the provider or changing the remote site.

Review the site's `site.url` before publication: GitHub Pages project sites need the repository subpath, for example `https://username.github.io/project/`. Zeta does not automatically enable Pages settings or create remote Cloudflare projects. The configured publishing repository or Pages project must already exist.

Credentials are delegated to Git Credential Manager, GitHub CLI, or Wrangler. Keep `deploy.conf` private if it contains internal repository or account identifiers; it contains no passwords.
