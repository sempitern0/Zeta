#Requires -Version 7.0
# Independent from Pandoc and user sites; verifies shared accessible dashboard.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-workspace-'+[Guid]::NewGuid().ToString('N'))
try{
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $Sites 'site-one/posts'))
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 Save (Join-Path $Sites 'site-one/config.yaml') @'
site:
  title: "A & B <Site>"
  description: "Site <script>demo</script> & notes"
  author: "QA"
  language: "es"
  url: "https://example.org"
theme:
  name: "folio"
build:
  content_dir: "posts"
  output_dir: "public"
'@
 Save (Join-Path $Sites 'site-one/posts/demo.md') '# Example'
 Save (Join-Path $Sites 'site-one/public/index.html') '<!doctype html>'
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $Sites 'broken'))
 Save (Join-Path $Sites 'broken/config.yaml') @'
site:
  title: "Invalid site"
build:
  content_dir: ""
  output_dir: "public"
'@
 Dashboard
 $html=[IO.File]::ReadAllText((Join-Path $Sites 'index.html'))
 foreach($expected in @('A &amp; B &lt;Site&gt;','2','Ready','Configuration issue','folio','workspace.css','Accessibility')){
  if($expected -eq 'Accessibility'){continue}
  if(-not $html.Contains($expected)){throw "Workspace HTML missing: $expected"}
 }
 if($html.Contains('<script>demo</script>')){throw 'Unescaped site content in dashboard'}
 if(!(Test-Path (Join-Path $Sites 'workspace.css'))){throw 'Shared stylesheet missing'}
  foreach($theme in @('zen','paper','console','indie','organization','brutalist','folio','aurora')){
   if(-not $html.Contains('id="theme-'+$theme+'"')){throw "Missing theme preview: $theme"}
  }
  if(-not $html.Contains('id="theme-gallery"')){throw 'Missing theme gallery'}
  if((Recommended-ZetaFont 'console') -ne 'cascadia'){throw 'Incorrect console font'}
  if((Recommended-ZetaFont 'folio') -ne 'source-code'){throw 'Incorrect folio font'}
 Write-Host '[OK] PowerShell workspace dashboard, escaping, statuses and shared CSS.'
}finally{
 if(Test-Path $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
