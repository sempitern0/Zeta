#Requires -Version 7.0
# A malformed site must not block listing, managing or confirmed deletion.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)
$Force=$false
$Port=8000
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-recovery-'+[guid]::NewGuid().ToString('N'))
try {
 New-Item -ItemType Directory -Force -Path (Join-Path $Sites 'broken') | Out-Null
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 . (Join-Path $Root 'lib/powershell/Console.ps1')
 Save (Join-Path $Sites 'broken/config.yaml') @'
site:
  title: "Broken example"
build:
  content_dir: ""
  output_dir: "public"
'@
 ListSites
 function Clear-Host {}
 $script:answers=[Collections.Generic.Queue[string]]::new()
 foreach($choice in @('10','broken','')){ $script:answers.Enqueue($choice) }
 function Read-Host {
  param([string]$Prompt)
  if(!$script:answers.Count){throw "Unexpected prompt: $Prompt"}
  return $script:answers.Dequeue()
 }
 Manage-Menu 'broken'
 if(Test-Path (Join-Path $Sites 'broken')){throw 'Confirmed deletion did not remove the broken site'}
 Write-Host '[OK] Malformed site can be listed and deleted.'
} finally {
 if(Test-Path $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
