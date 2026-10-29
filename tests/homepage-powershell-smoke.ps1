#Requires -Version 7.0
# Homepage and new editorials, without any external provider access.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-home-'+[guid]::NewGuid().ToString('N'))
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
. (Join-Path $Root 'lib/powershell/Dependencies.ps1')
. (Join-Path $Root 'lib/powershell/Core.ps1')
. (Join-Path $Root 'lib/powershell/Homepage.ps1')
try{
 $name='editorial'
 $site=Join-Path $Sites $name
 [void](New-Item -ItemType Directory -Path (Join-Path $site 'pages'),(Join-Path $site 'posts') -Force)
 $config=@'
site:
  title: "Editorial test"
  description: "Publication"
  author: "Editor"
  language: "en"
  url: "https://example.org"
theme:
  name: "paper"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: true
homepage:
  show_posts: true
  posts_limit: 1
'@
 Save (Join-Path $site 'config.yaml') $config
 Save (Join-Path $site 'pages/index.md') "---`ntitle: Home`ndescription: Index`n---`n# Local introduction`n`nThis introduction is retained."
 foreach($item in @('one','two')){
  Save (Join-Path $site "posts/2026-10-20-$item.md") "---`ntitle: Headline $item`ndate: 2026-10-20`ndescription: Summary $item`nauthor: Editor`n---`n`nArticle body"
 }
 foreach($theme in @('zen','paper','console','indie','organization','brutalist','folio','aurora','gazette','magazine')){
  $text=[IO.File]::ReadAllText((Join-Path $site 'config.yaml'))
  $text=[regex]::Replace($text,'(?m)^  name: ".*"$','  name: "'+$theme+'"')
  Save (Join-Path $site 'config.yaml') $text
  Build $name
  $index=[IO.File]::ReadAllText((Join-Path $site 'public/index.html'))
  if(!$index.Contains('Local introduction') -or !$index.Contains('zeta-home-story')){throw "Homepage missing feed: $theme"}
  if(([regex]::Matches($index,'class="zeta-home-story"')).Count -ne 1){throw "posts_limit not honored: $theme"}
  if(!(Test-Path -LiteralPath (Join-Path $site 'public/posts.html'))){throw "Missing posts archive: $theme"}
 }
 Set-ZetaHomepage $name 'false' '3'
 Build $name
 if([IO.File]::ReadAllText((Join-Path $site 'public/index.html')).Contains('zeta-home-story')){throw 'show_posts=false not honored'}
 Write-Host '[OK] Ten PowerShell theme homepages, feed limits and preferences' -ForegroundColor Green
}finally{if(Test-Path -LiteralPath $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}}
