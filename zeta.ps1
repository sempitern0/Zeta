#Requires -Version 7.0
param(
 [Parameter(Position=0)][string]$Command='',
 [Parameter(Position=1)][string]$Site='',
 [Parameter(Position=2)][string]$Value='',
 [Parameter(Position=3)][string]$Highlight='',
 [switch]$Force,
 [switch]$Yes,
 [int]$Port=8000
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$Sites=Join-Path $Root 'sites'
$Templates=Join-Path $Root 'templates'
$Utf8=[Text.UTF8Encoding]::new($false)

. (Join-Path $Root 'lib/powershell/Dependencies.ps1')
. (Join-Path $Root 'lib/powershell/Core.ps1')
. (Join-Path $Root 'lib/powershell/Workspace.ps1')
. (Join-Path $Root 'lib/powershell/Console.ps1')
. (Join-Path $Root 'lib/powershell/Doctor.ps1')

try {
 switch($Command.ToLowerInvariant()){
  ''{Menu}
  'help'{Help}
  '--help'{Help}
  '-h'{Help}
  'sites'{ListSites}
  'list'{ListSites}
  'create'{NewSite}
  'new'{NewSite}
  'deps'{Show-ZetaDependencies}
  'dependencies'{Show-ZetaDependencies}
  'install-pandoc'{[void](Install-ZetaPandoc -AssumeYes:$Yes)}
  'edit'{EditSite $Site}
  'theme'{ThemeSite $Site $Value $Highlight}
  'appearance'{ThemeSite $Site $Value $Highlight}
  'posts'{ListPosts $Site}
  'new-post'{NewPost $Site}
  'pages'{ListPages $Site}
  'new-page'{NewPage $Site $Value $Highlight}
  'build'{if($Site){Build $Site}else{foreach($n in (SiteNames)){Build $n}};Dashboard}
  'update'{if($Site){Build $Site}else{foreach($n in (SiteNames)){Build $n}};Dashboard}
  'build-all'{foreach($n in (SiteNames)){Build $n};Dashboard}
  'doctor'{Doctor $Site}
  'diagnose'{Doctor $Site}
  'check-site'{Doctor $Site}
  'preview'{Preview $Site $Port}
  'serve'{if($Site){if($Site -notmatch '^[0-9]{1,5}$'){throw 'Invalid server port'};$Port=[int]$Site};foreach($n in (SiteNames)){Build $n};Dashboard;Serve $Sites $Port}
  'dashboard'{Dashboard}
  'index'{Dashboard}
  'clean'{Clean $Site}
  'delete'{RemoveSite $Site}
  'rm'{RemoveSite $Site}
  'fonts'{FontSite $Site $Value}
  default{throw "Unknown command: $Command"}
 }
}catch{Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red;exit 1}
