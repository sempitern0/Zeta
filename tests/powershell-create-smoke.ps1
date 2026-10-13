#Requires -Version 7.0
# Local regression: creates a site in a temporary workspace, without GitHub CI or Pandoc.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repository=Split-Path -Parent $PSScriptRoot
$Root=$repository
$Templates=Join-Path $repository 'templates'
$folder=Join-Path ([IO.Path]::GetTempPath()) ('zeta-create-'+[guid]::NewGuid().ToString('N'))
$Sites=Join-Path $folder 'sites'
$Utf8=[Text.UTF8Encoding]::new($false)
$Force=$false
try{
 [void](New-Item -ItemType Directory -Path $Sites -Force)
 . (Join-Path $Root 'lib/powershell/Dependencies.ps1')
 . (Join-Path $Root 'lib/powershell/Core.ps1')
 . (Join-Path $Root 'lib/powershell/Workspace.ps1')
 # The test is independent of system Pandoc and never runs winget.
 function Test-ZetaPandoc { return $false }
 function Install-ZetaPandoc { return $false }
 $script:replies=[Collections.Generic.Queue[string]]::new()
 foreach($value in @('Zeta Test','','organization','Test description','QA','https://example.org')){
  $script:replies.Enqueue($value)
 }
 function Read-Host {
  param([string]$Prompt)
  if($script:replies.Count -eq 0){throw "Unexpected prompt: $Prompt"}
  return $script:replies.Dequeue()
 }
 NewSite
 $site=Join-Path $Sites 'zeta-test'
 if(!(Test-Path (Join-Path $site 'config.yaml'))){throw 'Site config missing'}
 $config=Config 'zeta-test'
 if($config.theme -ne 'organization'){throw 'Theme selection failed'}
 if(@(Get-ChildItem (Join-Path $site 'posts') -Filter '*.md').Count -ne 1){throw 'Welcome post missing'}
 if(@(SiteNames) -notcontains 'zeta-test'){throw 'Site not discoverable'}
 $script:replies.Clear()
 foreach($value in @('Zeta Test','','organization')){$script:replies.Enqueue($value)}
 $failed=$false
 try{NewSite}catch{$failed=$true}
 if(!$failed){throw 'Duplicate site must be rejected'}
 if(!(Test-Path (Join-Path $site 'config.yaml'))){throw 'Duplicate removed original config'}
 Write-Host '[OK] Site creation, theme choice, source files and duplicate protection.' -ForegroundColor Green
}finally{
 Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}

