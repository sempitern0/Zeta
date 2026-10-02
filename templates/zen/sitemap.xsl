<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:s="http://www.sitemaps.org/schemas/sitemap/0.9">
  <xsl:output method="html" encoding="UTF-8"/>
  <xsl:template match="/">
    <html lang="en">
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <title>Sitemap</title>
        <style>
          body{font-family:system-ui,sans-serif;max-width:72rem;margin:2rem auto;padding:0 1rem;line-height:1.5}
          table{width:100%;border-collapse:collapse}th,td{padding:.6rem;border-bottom:1px solid #ccc;text-align:left}
          code{overflow-wrap:anywhere}
        </style>
      </head>
      <body>
        <h1>Sitemap</h1>
        <table>
          <thead><tr><th>URL</th><th>Last modified</th></tr></thead>
          <tbody>
            <xsl:for-each select="s:urlset/s:url">
              <tr>
                <td><code><xsl:value-of select="s:loc"/></code></td>
                <td><xsl:value-of select="s:lastmod"/></td>
              </tr>
            </xsl:for-each>
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
