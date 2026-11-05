#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
. (Join-Path $Root 'lib/powershell/Core.ps1')
$site='zeta-category-ps-'+[guid]::NewGuid().ToString('N')
$path=Join-Path $Root "sites/$site"
try{
 New-Item -ItemType Directory -Force -Path (Join-Path $path 'pages'),(Join-Path $path 'posts')|Out-Null
 [IO.File]::WriteAllText((Join-Path $path 'pages/index.md'),"---`ntitle: Home`nnav: true`n---`n# Markdown homepage marker`n")
 [IO.File]::WriteAllText((Join-Path $path 'pages/about.md'),"---`ntitle: About`nnav: true`n---`n# About page marker`n")
 foreach($theme in @('music','cuisine','spirituality','photography','store','services')){
  $yaml=@"
site:
  title: "Category"
  description: "Example"
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
homepage:
  layout: theme
  show_posts: false
"@
  [IO.File]::WriteAllText((Join-Path $path 'config.yaml'),$yaml)
  Build $site
  $index=[IO.File]::ReadAllText((Join-Path $path 'public/index.html'))
  if(-not $index.Contains("theme-$theme") -or -not $index.Contains('href="./about/"')){throw "$theme landing unavailable"}
  if($index.Contains('Markdown homepage marker')){throw "$theme replaced by Markdown"}
  if(-not (Test-Path (Join-Path $path 'public/about/index.html'))){throw "$theme missing About"}
  if(Test-Path (Join-Path $path 'public/posts.html')){throw "$theme unexpectedly created archive"}
 }
 Write-Host '[OK] PowerShell category landing layouts'
}finally{
 if(Test-Path $path){Remove-Item -LiteralPath $path -Force -Recurse}
}
