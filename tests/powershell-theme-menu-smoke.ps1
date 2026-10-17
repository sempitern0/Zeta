#Requires -Version 7.0
# Offline regression: theme menu must preserve site paths and arbitrary YAML keys.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-theme-menu-'+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $temp 'sites'
try {
 $siteDir=Join-Path $Sites 'test-site'
 New-Item -ItemType Directory -Force -Path $siteDir | Out-Null
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 $yaml=@'
site:
  title: "Example"
  author: "QA"
  language: "en"
  url: "https://example.org"
  custom: "keep"
theme:
  name: "zen"
  pandoc_theme: "zenburn"
build:
  content_dir: "posts"
  output_dir: "public"
  special: "keep"
'@
 $path=Join-Path $siteDir 'config.yaml'
 Save $path $yaml
 $script:choices=[Collections.Generic.Queue[string]]::new()
 $script:choices.Enqueue('2')
 $script:choices.Enqueue('1')
 $script:choices.Enqueue('N')
 function Read-Host {
  param([string]$Prompt)
  if(-not $script:choices.Count){throw "Unexpected prompt: $Prompt"}
  $script:choices.Dequeue()
 }
 function Get-ZetaHighlightStyles { @('pygments','zenburn') }
 function Build([string]$name) {
  $c=Config $name
  if($c.content -ne 'posts' -or $c.output -ne 'public'){throw 'Paths were modified'}
  if($c.theme -ne 'brutalist' -or $c.highlight -ne 'pygments'){throw 'Theme was not applied'}
 }
 function Dashboard {}
 ThemeSite 'test-site' '' ''
 $after=[IO.File]::ReadAllText($path)
 if($script:choices.Count -ne 0){throw 'Prompts not consumed'}
 foreach($field in @('custom: "keep"','special: "keep"','content_dir: "posts"','output_dir: "public"')){
  if(-not $after.Contains($field)){throw "Lost config value: $field"}
 }
 $before=[IO.File]::ReadAllBytes($path)
 function Build([string]$name) { throw 'Simulated build error' }
 try {ThemeSite 'test-site' 'folio' 'zenburn';throw 'Failure was not propagated'}
 catch {if($_.Exception.Message -eq 'Failure was not propagated'){throw}}
 $restored=[IO.File]::ReadAllBytes($path)
 if([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String($restored)){throw 'Failed build changed site config'}
 Write-Host '[OK] Theme choices, preserved build paths, and rollback.'
} finally {
 if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
