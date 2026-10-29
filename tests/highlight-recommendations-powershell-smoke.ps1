#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$Templates=Join-Path $Root 'templates'
$Sites=Join-Path $Root 'sites'
. (Join-Path $Root 'lib/powershell/Core.ps1')
. (Join-Path $Root 'lib/powershell/Workspace.ps1')
foreach($theme in @('zen','paper','console','indie','organization','brutalist','folio','aurora','gazette','magazine')){
 $rec=Get-ZetaHighlightRecommendation $theme
 if(!$rec.Primary -or !$rec.Reason){throw "Missing recommendation for $theme"}
 if($rec.Primary -notin @(Get-ZetaHighlightStyles)){throw "Unavailable recommendation: $theme"}
}
if((Get-ZetaHighlightRecommendation 'paper').Primary -ne 'tango'){throw 'Paper should recommend tango'}
if((Get-ZetaHighlightRecommendation 'console').Primary -ne 'breezedark'){throw 'Console should recommend breezedark'}
Write-Host '[OK] Ten theme-specific PowerShell highlight recommendations'
