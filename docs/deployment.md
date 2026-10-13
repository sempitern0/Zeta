# Deploying Zeta sites

[← Project overview](../README.md)

A Zeta build produces plain HTML, CSS and static assets. The entire deployable artifact is **`sites/<site>/public/`**. Do not publish the original `posts/`, `config.yaml`, or other authoring files.

## Before deployment

1. Set `site.url` in `config.yaml` to the actual public URL. On GitHub Pages project sites include the repository subpath (for example `https://username.github.io/project`).
2. Build with `./zeta.sh build SITE` (Bash) or `.\zeta.ps1 build SITE` (PowerShell).
3. Run `doctor SITE` and check a local preview.
4. Upload or publish the generated `public/` folder.

Zeta uses the configured URL in `robots.txt` and `sitemap.xml`; navigation links are relative so sites can be hosted at a domain root or subpath.

## Static hosting

| Provider | Method |
| :-- | :-- |
| [Netlify](https://docs.netlify.com/start/quickstarts/netlify-drop-quickstart/) | Drop the generated static files |
| [Cloudflare Pages](https://developers.cloudflare.com/pages/get-started/direct-upload/) | Direct Upload of the prebuilt assets |
| [GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site) | Publish generated files from a dedicated branch or repository |
| [Vercel](https://vercel.com/docs) | Deploy prebuilt static files using a supported static configuration |

Zeta deliberately avoids storing hosting credentials or depending on deployment SDKs. GitHub Actions is **not required** for publishing.

## Protect your sources

The generator stages output before replacing `public/`. Keep backups of your Markdown, YAML and site-local assets. `clean SITE` removes generated output, not source files.

For projects and game landing pages, see [landing themes](landing-themes.md).
