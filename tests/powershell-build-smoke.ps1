#Requires -Version 7.0
# Local PowerShell/Pandoc rendering regression. No GitHub Actions, remote calls,
# Windows package installation, or modification of real user sites.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-pandoc-'+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $temp 'sites'
try{
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){
  throw 'Pandoc is required for this smoke test. Install it with ./zeta.ps1 install-pandoc on Windows.'
 }
 [void](New-Item -ItemType Directory -Path $Sites -Force)
 . (Join-Path $Root 'lib/powershell/Dependencies.ps1')
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 $themes=@('zen','paper','console','indie','organization','brutalist','folio','aurora')
 foreach($theme in $themes){
  if(@(Themes) -notcontains $theme){throw "Expected theme missing: $theme"}
  $site='zeta-pandoc-'+$theme
  $siteDir=Join-Path $Sites $site
  [void](New-Item -ItemType Directory -Path (Join-Path $siteDir 'posts') -Force)
  $yaml=@"
site:
  title: "Pandoc Smoke"
  description: "Template regression test"
  author: "Zeta QA"
  language: "en"
  url: "https://example.org/zeta"
theme:
  name: "$theme"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
"@
  Save (Join-Path $siteDir 'config.yaml') $yaml
  $post=@'
---
title: "Test article"
description: "A Markdown publishing test."
author: "Zeta QA"
date: "2026-10-12"
---

# Hello Zeta

This is an **article**.
'@
  Save (Join-Path $siteDir 'posts/2026-10-12-smoke.md') $post
  Build $site
  # Regression: organization hero must compile with and without an image.
  if($theme -eq 'organization'){
   $tpl=Join-Path $Templates 'organization/index.html'
   foreach($variant in @('without','with')){
    $args=@('-f','markdown','-t','html5','--standalone','--template',$tpl,'-V','site_lang=en')
    if($variant -eq 'with'){$args+=@('-V','hero_image=assets/example.webp')}
    $rendered=('' | & pandoc @args) -join [Environment]::NewLine
    if($LASTEXITCODE -ne 0 -or $rendered -notmatch 'hero-grid'){throw "Organization hero failed: $variant image"}
   }
  }
  $public=Join-Path $siteDir 'public'
  foreach($file in @('index.html','posts.html','posts/2026/smoke.html','styles/normalize.css','styles/markdown.css','sitemap.xml','robots.txt')){
   $path=Join-Path $public $file
   if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "$theme failed to generate $file"}
  }
  $index=[IO.File]::ReadAllText((Join-Path $public 'index.html'))
  if($index -notmatch '(?i)<html'){throw "$theme did not apply the HTML template"}
  if(-not $index.Contains('rel="canonical" href="https://example.org/zeta/"')){throw "$theme missing home canonical"}
  if(-not $index.Contains('og:type" content="website"')){throw "$theme missing Open Graph"}
  if(([regex]::Matches($index,'rel="canonical"')).Count -ne 1){throw "$theme duplicates canonical"}
  if(([regex]::Matches($index,'name="description"')).Count -ne 1){throw "$theme duplicates description"}
  $article=[IO.File]::ReadAllText((Join-Path $public 'posts/2026/smoke.html'))
  if($article -notmatch 'Hello Zeta'){throw "$theme article has no Markdown content"}
  if(-not $article.Contains('rel="canonical" href="https://example.org/zeta/posts/2026/smoke.html"')){throw "$theme article canonical incorrect"}
  if(-not $article.Contains('og:type" content="article"')){throw "$theme missing article metadata"}

  Write-Host "[OK] $theme rendered with absolute templates" -ForegroundColor Green
 }
 Write-Host '[OK] All eight themes generated on PowerShell.' -ForegroundColor Green
}
finally{
 if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
