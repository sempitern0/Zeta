<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:html="http://www.w3.org/TR/REC-html40"
  xmlns:sitemap="http://www.sitemaps.org/schemas/sitemap/0.9"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml" lang="es">
    <head>
      <title>XML Sitemap</title>
      <meta charset="utf-8" />
      <style>
        body {
          font-family: "JetBrains Mono", system-ui, -apple-system, sans-serif;
          background-color: #0d1117;
          color: #e6edf3;
          padding: 2rem;
          margin: 0;
        }
        .header { margin-bottom: 2rem; border-bottom: 1px solid #30363d; padding-bottom: 1rem; }
        h1 { color: #3fb950; font-size: 1.5rem; margin: 0 0 0.5rem 0; }
        h1::before { content: "# "; color: #8b949e; }
        p { color: #8b949e; margin: 0; font-size: 0.95rem; }
        table { width: 100%; border-collapse: collapse; background: #161b22; border-radius: 6px; overflow: hidden; border: 1px solid #30363d; margin-top: 1rem; }
        th, td { padding: 0.75rem 1rem; text-align: left; font-size: 0.9rem; }
        th { background: #161b22; color: #58a6ff; font-weight: 600; border-bottom: 1px solid #30363d; }
        td { border-bottom: 1px solid #21262d; }
        tr:hover td { background: #21262d; }
        a { color: #58a6ff; text-decoration: none; word-break: break-all; }
        a:hover { text-decoration: underline; color: #3fb950; }
        .badge { background: #21262d; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; color: #8b949e; border: 1px solid #30363d; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>XML Sitemap</h1>
        <p>Mapa del sitio optimizado para motores de búsqueda. Contiene <xsl:value-of select="count(sitemap:urlset/sitemap:url)"/> direcciones URL.</p>
      </div>
      <table>
        <thead>
          <tr>
            <th>URL</th>
            <th>Última modificación</th>
            <th>Prioridad</th>
          </tr>
        </thead>
        <tbody>
          <xsl:for-each select="sitemap:urlset/sitemap:url">
            <tr>
              <td>
                <a href="{sitemap:loc}"><xsl:value-of select="sitemap:loc"/></a>
              </td>
              <td><span class="badge"><xsl:value-of select="sitemap:lastmod"/></span></td>
              <td><span class="badge"><xsl:value-of select="sitemap:priority"/></span></td>
            </tr>
          </xsl:for-each>
        </tbody>
      </table>
    </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
