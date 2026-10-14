#Requires -Version 7.0
# Read-only local diagnostics; does not run GitHub Actions.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-doctor-'+[guid]::NewGuid().ToString('N'))
try{
 if(-not (Get-Command pandoc -ErrorAction SilentlyContinue)){throw 'Pandoc required'}
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Doctor.ps1')
 $site=Join-Path $Sites 'smoke'
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $site 'pages'),(Join-Path $site 'posts'))
 Save (Join-Path $site 'config.yaml') @'
site:
  title: "Doctor smoke"
  description: "Content diagnostics"
  author: "QA"
  language: "en"
  url: "https://example.org"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  blog: false
'@
 $script:checks=[Collections.Generic.List[string]]::new()
 function DoctorStatus([hashtable]$state,[string]$level,[string]$label,[string]$detail){
  if($level -eq 'FAIL'){$state.errors++}elseif($level -eq 'WARN'){$state.warnings++}
  $script:checks.Add("$level|$label|$detail")
 }
 Save (Join-Path $site 'pages/index.md') @'
---
title: "Home"
---
[Missing](absent.md)

![no file](../assets/missing.png)

[](javascript:alert)
'@
 try{Doctor 'smoke'}catch{}
 foreach($expected in @('BROKEN_LINK','MISSING_IMAGE','UNSAFE_URL')){
  if(-not (@($script:checks | Where-Object {$_ -match $expected}).Count)){
   throw "Doctor did not report $expected"
  }
 }
 $script:checks.Clear()
 Save (Join-Path $site 'pages/index.md') @'
---
title: ""Broken""
---
Content
'@
 try{Doctor 'smoke'}catch{}
 if(-not (@($script:checks | Where-Object {$_ -match 'Markdown parse'}).Count)){
  throw 'Doctor did not report malformed YAML'
 }
 Write-Host '[OK] PowerShell Doctor reports broken links and malformed YAML without editing sources.' -ForegroundColor Green
}finally{Remove-Item -LiteralPath $Sites -Force -Recurse -ErrorAction SilentlyContinue}
