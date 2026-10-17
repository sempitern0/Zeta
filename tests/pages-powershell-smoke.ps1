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
  $buildOutput=@(Build $name)
  if($buildOutput.Count -ne 0){throw "$theme build unexpectedly emitted pipeline output: $($buildOutput -join ', ')"}
  $out=Join-Path $site 'public'
  foreach($path in @('index.html','about/index.html','styles/zeta-pages.css','sitemap.xml')){
   if(!(Test-Path (Join-Path $out $path))){throw "$theme missing $path"}
  }
  foreach($path in @('draft/index.html','posts.html','posts/2026/hidden.html','rss.xml','atom.xml')){
   if(Test-Path (Join-Path $out $path)){throw "$theme unexpectedly published $path"}
  }
  foreach($cssFile in @('styles/zeta-navigation.css','styles/00-theme-contract.css')){
   if(!(Test-Path (Join-Path $out $cssFile))){throw "$theme missing $cssFile"}
  }
  $themeContract=[IO.File]::ReadAllText((Join-Path $out 'styles/00-theme-contract.css'))
  if(-not $themeContract.Contains('--zeta-nav-background')){throw "$theme missing navigation contract"}
  $sharedCss=[IO.File]::ReadAllText((Join-Path $out 'styles/zeta-pages.css'))
  if($sharedCss -match 'zeta-theme-(zen|paper|console|indie|organization|brutalist|folio|aurora)'){throw "Theme styling leaked into shared core"}
  $index=[IO.File]::ReadAllText((Join-Path $out 'index.html'))
  foreach($pagePath in @('index.html','about/index.html')){
   $pageHtml=[IO.File]::ReadAllText((Join-Path $out $pagePath))
   if(-not $pageHtml.Contains('zeta-theme-'+$theme)){throw "$theme missing page theme identity: $pagePath"}
   if(-not $pageHtml.Contains('styles/theme.css') -and $theme -ne 'zen'){throw "$theme missing theme stylesheet: $pagePath"}
   if(-not $pageHtml.Contains('styles/zeta-pages.css')){throw "$theme missing shared page CSS: $pagePath"}
  }
  $about=[IO.File]::ReadAllText((Join-Path $out 'about/index.html'))
  $sitemap=[IO.File]::ReadAllText((Join-Path $out 'sitemap.xml'))
  if(-not $index.Contains('href="./about/"')){throw "$theme did not rewrite about.md"}
  if(-not $about.Contains('href="../index.html#content"')){throw "$theme did not rewrite index.md"}
  if(-not $sitemap.Contains('https://example.org/about/')){throw "$theme sitemap missing About"}
  if($sitemap.Contains('/posts/')){throw "$theme blog is disabled but post URLs remain"}
  # Blog and article navigation must remain functional in every theme.
  $configPath=Join-Path $site 'config.yaml'
  $originalConfig=[IO.File]::ReadAllText($configPath)
  Save $configPath ($originalConfig.Replace('blog: false','blog: true'))
  Build $name
  $blogHtml=[IO.File]::ReadAllText((Join-Path $out 'posts.html'))
  $postHtml=[IO.File]::ReadAllText((Join-Path $out 'posts/2026/hidden.html'))
  foreach($token in @('href="./about/"','href="./index.html"','aria-current="page"')){
   if(-not $blogHtml.Contains($token)){throw "$theme blog navigation missing $token"}
  }
  if(-not $postHtml.Contains('href="../../about/"')){throw "$theme article navigation missing About"}
  if($blogHtml.Contains('>page_navigation<') -or $postHtml.Contains('>page_navigation<')){throw "$theme has literal navigation placeholder"}
  Save $configPath $originalConfig
  Write-Host "[OK] $theme pages without blog" -ForegroundColor Green
 }
 # Regression: blog navigation must keep all visible Markdown pages.
 $navSite=Join-Path $Sites 'pages-paper'
 $navConfig=Join-Path $navSite 'config.yaml'
 Save $navConfig ([IO.File]::ReadAllText($navConfig).Replace('blog: false','blog: true'))
 Build 'pages-paper'
 $archive=[IO.File]::ReadAllText((Join-Path $navSite 'public/posts.html'))
 if($archive -match '>page_navigation<'){throw 'Pandoc rendered the navigation variable literally'}
 $article=[IO.File]::ReadAllText((Join-Path $navSite 'public/posts/2026/hidden.html'))
 if(-not $article.Contains('href="../../about/"')){throw "Article lost About navigation"}
 foreach($token in @('href="./index.html"','href="./about/"','aria-current="page"')){
  if(-not $archive.Contains($token)){throw "Blog lost navigation: $token"}
 }
 # Regression: new page must bootstrap a missing homepage and preserve it.
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 $target=Join-Path $Sites 'pages-zen'
 Remove-Item -LiteralPath (Join-Path $target 'pages/index.md') -Force
 NewPage 'pages-zen' 'Privacy Policy' 'privacy'
 $recovered=[IO.File]::ReadAllText((Join-Path $target 'pages/index.md'))
 if($recovered -notmatch '(?m)^title: "Page smoke"$' -or $recovered -match '(?m)^title: ""'){
  throw 'Invalid generated YAML title'
 }
 if($recovered -notmatch '(?m)^description: "Test site"$'){throw 'Invalid generated YAML description'}
 $null=& pandoc --from markdown --to html (Join-Path $target 'pages/index.md')
 if($LASTEXITCODE -ne 0){throw 'Pandoc rejected recovered homepage frontmatter'}
 if(-not (Test-Path -LiteralPath (Join-Path $target 'public/privacy/index.html'))){throw 'New page was not built'}
 $homepage=[IO.File]::ReadAllText((Join-Path $target 'pages/index.md'))
 Build 'pages-zen'
 if([IO.File]::ReadAllText((Join-Path $target 'pages/index.md')) -cne $homepage){throw 'Existing homepage was overwritten'}

 # Existing malformed homepage is repaired without touching Markdown body.
 $damaged=$homepage -replace '(?m)^title: "Page smoke"$','title: ""Page smoke""'
 Save (Join-Path $target 'pages/index.md') $damaged
 Build 'pages-zen'
 $after=[IO.File]::ReadAllText((Join-Path $target 'pages/index.md'))
 if($after -cne $homepage){throw 'Repair did not restore original valid YAML'}
 $backups=@(Get-ChildItem -LiteralPath (Join-Path $target 'pages') -Filter 'index.md.zeta-backup-*.bak')
 if($backups.Count -ne 1){throw 'No backup produced for corrected malformed frontmatter'}
 if([IO.File]::ReadAllText($backups[0].FullName) -cne $damaged){throw 'Backup did not preserve original malformed file'}
 Write-Host '[OK] Homepage bootstrap, Pandoc parse, backup and non-destructive repair.' -ForegroundColor Green
}
finally {
 if(Test-Path $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
