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
          font-family: system-ui, -apple-system, sans-serif;
          background-color: #f8f9fa;
          color: #212529;
          padding: 2rem;
          margin: 0;
        }
        .header { margin-bottom: 2rem; border-bottom: 1px solid #dee2e6; padding-bottom: 1rem; }
        h1 { font-size: 1.5rem; margin: 0 0 0.5rem 0; color: #0d6efd; }
        p { color: #6c757d; margin: 0; font-size: 0.95rem; }
        table { width: 100%; border-collapse: collapse; background: #ffffff; border-radius: 6px; overflow: hidden; border: 1px solid #dee2e6; margin-top: 1rem; }
        th, td { padding: 0.75rem 1rem; text-align: left; font-size: 0.9rem; }
        th { background: #f1f3f5; color: #495057; font-weight: 600; border-bottom: 1px solid #dee2e6; }
        td { border-bottom: 1px solid #e9ecef; }
        tr:hover td { background: #f8f9fa; }
        a { color: #0d6efd; text-decoration: none; word-break: break-all; }
        a:hover { text-decoration: underline; }
        .badge { background: #e9ecef; padding: 2px 8px; border-radius: 4px; font-size: 0.85rem; color: #495057; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>XML Sitemap</h1>
        <p>Mapa del sitio generado automáticamente. Contiene <xsl:value-of select="count(sitemap:urlset/sitemap:url)"/> direcciones URL.</p>
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