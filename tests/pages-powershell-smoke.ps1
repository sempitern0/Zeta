#Requires -Version 7.0
# Generates all eight themes without a blog using only Markdown pages.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-pages-'+[guid]::NewGuid().ToString('N'))
try {
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){throw 'Pandoc required'}
 . (Join-Path $Root 'lib/powershell/Dependencies.ps1')
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 foreach($theme in @('zen','paper','console','indie','organization','brutalist','folio','aurora')){
  $name='pages-'+$theme
  $site=Join-Path $Sites $name
  [void](New-Item -ItemType Directory -Path (Join-Path $site 'pages'),(Join-Path $site 'posts') -Force)
  Save (Join-Path $site 'config.yaml') @"
site:
  title: "Page smoke"
  description: "Test site"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
"@
  Save (Join-Path $site 'pages/index.md') @'
---
title: "Home"
description: "Static home"
nav: true
nav_order: 0
---
Welcome! [About](about.md).
'@
  Save (Join-Path $site 'pages/about.md') @'
---
title: "About"
description: "About us"
nav: true
nav_order: 20
---
## Our mission

[Return home](index.md#content).
'@
  Save (Join-Path $site 'pages/draft.md') @'
---
title: "Draft"
draft: true
---
Do not publish.
'@
  Save (Join-Path $site 'posts/2026-10-13-hidden.md') @'
---
title: "Hidden blog"
date: "2026-10-13"
---
Should not publish.
'@
  Build $name
  $out=Join-Path $site 'public'
  foreach($path in @('index.html','about/index.html','styles/zeta-pages.css','sitemap.xml')){
   if(!(Test-Path (Join-Path $out $path))){throw "$theme missing $path"}
  }
  foreach($path in @('draft/index.html','posts.html','posts/2026/hidden.html')){
   if(Test-Path (Join-Path $out $path)){throw "$theme unexpectedly published $path"}
  }
  $index=[IO.File]::ReadAllText((Join-Path $out 'index.html'))
  $about=[IO.File]::ReadAllText((Join-Path $out 'about/index.html'))
  $sitemap=[IO.File]::ReadAllText((Join-Path $out 'sitemap.xml'))
  if(-not $index.Contains('href="./about/"')){throw "$theme did not rewrite about.md"}
  if(-not $about.Contains('href="../index.html#content"')){throw "$theme did not rewrite index.md"}
  if(-not $sitemap.Contains('https://example.org/about/')){throw "$theme sitemap missing About"}
  if($sitemap.Contains('/posts/')){throw "$theme blog is disabled but post URLs remain"}
  Write-Host "[OK] $theme pages without blog" -ForegroundColor Green
 }
}
finally {
 if(Test-Path $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
