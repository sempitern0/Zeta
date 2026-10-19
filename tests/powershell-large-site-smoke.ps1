#Requires -Version 7.0
# Exercise native argument limits on every platform, including Linux CI.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta large site '+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $temp 'sites'
try {
 . (Join-Path $Root 'lib/powershell/Dependencies.ps1')
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 $originalPandoc=${function:Invoke-ZetaPandoc}
 function Invoke-ZetaPandoc([string[]]$options) {
  # Leave room for executable paths, quoting and escaping in CreateProcess.
  if(($options -join ' ').Length -gt 30000){throw 'Generated HTML exceeded Windows native argument budget'}
  & $originalPandoc $options
 }
 $site=Join-Path $Sites 'example'
 [void](New-Item -ItemType Directory -Path (Join-Path $site 'posts') -Force)
 Save (Join-Path $site 'config.yaml') @'
site:
  title: "Large café & archive"
  description: "Large site regression"
  author: "QA"
  language: "es"
  url: "https://example.org"
theme:
  name: "aurora"
  pandoc_theme: "espresso"
build:
  content_dir: "posts"
  output_dir: "public"
'@
 $description='Archive text ' * 50
 foreach($number in 1..48){
  Save (Join-Path $site "posts/2026-10-18-entry-$number.md") "---`ntitle: Entry $number`ndate: 2026-10-18`ndescription: $description`n---`n`n## Section`n`nArticle $number."
 }
 $landing='<p data-check="raw-html">Café &amp; tea: `$literal$ \ path`</p>' + ('<p>Long landing body.</p>' * 2000)
 Save (Join-Path $site 'landing.md') $landing
 Build 'example'
 $archive=[IO.File]::ReadAllText((Join-Path $site 'public/posts.html'))
 foreach($number in 1..48){
  if(!$archive.Contains("posts/2026/entry-$number.html")){throw "Missing archive entry $number"}
 }
 $index=[IO.File]::ReadAllText((Join-Path $site 'public/index.html'))
 if(!$index.Contains('data-check="raw-html"') -or !$index.Contains('<code>$literal$ \ path</code>') -or ([regex]::Matches($index,'Long landing body\.')).Count -ne 2000){throw 'Landing HTML was escaped, parsed as metadata or truncated'}
 if(Get-ChildItem (Join-Path $site 'public') -Force -Filter '.zeta-*'){throw 'Internal build files leaked into public output'}
 Write-Host '[OK] Large archive and landing HTML with bounded native arguments.'
}finally{
 if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
