# Zeta PowerShell: terminal presentation and interactive navigation.
function Write-ZetaLine([string]$message,[string]$color='Gray'){
 if([Environment]::GetEnvironmentVariable('NO_COLOR') -ne $null){
  Write-Host $message
 }else{Write-Host $message -ForegroundColor $color}
}
function Show-Brand{
 $width=80
 try{$width=$Host.UI.RawUI.WindowSize.Width}catch{}
 $colors=@('Cyan','DarkCyan','Blue','DarkBlue','Magenta','DarkMagenta')
 $banner=@(
 '  ███████╗███████╗████████╗ █████╗ ',
 '  ╚══███╔╝██╔════╝╚══██╔══╝██╔══██╗',
 '    ███╔╝ █████╗     ██║   ███████║',
 '   ███╔╝  ██╔══╝     ██║   ██╔══██║',
 '  ███████╗███████╗   ██║   ██║  ██║',
 '  ╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝'
 )
 if($width -ge 69){
  for($i=0;$i -lt $banner.Count;$i++){Write-ZetaLine $banner[$i] $colors[$i]}
 }else{Write-ZetaLine '  ZETA' 'Cyan'}
 Write-ZetaLine '  Markdown-first Static Site Generator' 'Cyan'
 Write-ZetaLine ('─'*60) 'DarkGray'
 Write-Host ('  Workspace   {0} site(s) | Engine: PowerShell + Pandoc | Output: public/' -f @(SiteNames).Count)
 if(Get-Command pandoc -ErrorAction SilentlyContinue){
  Write-ZetaLine '  Pandoc: available | Preview: .NET built-in' 'Green'
 }else{Write-ZetaLine '  Pandoc: unavailable | Preview: .NET built-in' 'Yellow'}
 Write-ZetaLine ('─'*60) 'DarkGray'
}
function Show-Actions([string]$heading,[string[]]$options){
 Write-Host ''
 Write-ZetaLine ("  ◆ {0}" -f $heading) 'Magenta'
 foreach($option in $options){
  if($option -match '^(\[[^\]]+\])\s+(.*)$'){
   Write-ZetaLine ('    {0,-5} {1}' -f $Matches[1],$Matches[2]) 'White'
  }else{Write-Host ('    '+$option)}
 }
}
function Help{
 Show-Brand
 @'
Usage
  ./zeta.ps1                        Interactive assistant
  ./zeta.ps1 <command> [site] [value] [highlight]

Workspace
  sites | list                     List sites and status
  create | new                     Create a site
  edit SITE                        Edit site metadata
  theme | appearance SITE THEME    Switch theme and highlighting
  clean SITE                       Remove generated output only
  delete | rm SITE                 Delete site after confirmation

Content
  posts SITE                       List Markdown articles with metadata
  new-post SITE                    Create Markdown article
  fonts SITE [KEY]                 Manage optional local fonts
  doctor | diagnose SITE           Check deployment readiness

Build and preview
  build | update SITE              Build a site (omit SITE for all)
  build-all                        Build all sites
  preview SITE                     Build and preview a site
  serve                            Build and serve the workspace
  dashboard | index                Update the workspace index

PowerShell options
  -Force                           Skip deletion / overwrite confirmations
  -Port 8000                       Local preview port
  ./main.sh                        Legacy Bash entry point (Linux/macOS)

Requires PowerShell 7+; Pandoc required for builds.
'@ | Write-Host
}
function Manage-Menu([string]$name){
 while($true){
  Clear-Host
  Show-Brand
  $c=Config $name
  $status='draft'
  if(Test-Path (Join-Path (SiteDir $name) "$($c.output)/index.html")){$status='built'}
  Write-ZetaLine ("  Manage / {0}" -f $c.title) 'Cyan'
  Write-Host ('  {0} | {1} posts | {2} | {3}' -f $name,@(Posts $name).Count,$c.theme,$status)
  Show-Actions 'Content & appearance' @(
   '[1] Site settings','[2] Switch theme','[3] List posts','[4] New post','[5] Manage fonts')
  Show-Actions 'Build & validate' @(
   '[6] Doctor','[7] Build site','[8] Preview site')
  Show-Actions 'Maintenance' @(
   '[9] Clean output','[10] Delete site','[0] Back')
  $answer=Read-Host 'zeta / manage >'
  if($answer -in @('0','b','back')){return}
  try{
   switch($answer){
    '1'{EditSite $name}
    '2'{ThemeSite $name ''}
    '3'{ListPosts $name}
    '4'{NewPost $name}
    '5'{FontSite $name}
    '6'{Doctor $name}
    '7'{Build $name;Dashboard}
    '8'{Preview $name $Port}
    '9'{Clean $name;Dashboard}
    '10'{RemoveSite $name;return}
    default{Write-ZetaLine 'Unknown option.' 'Yellow'}
   }
  }catch{Write-ZetaLine ("[ERROR] {0}" -f $_.Exception.Message) 'Red'}
  [void](Read-Host 'Press Enter to continue')
 }
}
function Menu{
 while($true){
  Clear-Host
  Show-Brand
  Write-Host ''
  Write-ZetaLine '  ◆ Your sites' 'Magenta'
  $names=@(SiteNames)
  if(!$names.Count){Write-Host '    No sites yet. Choose [2] to create one.'}
  foreach($name in ($names | Select-Object -First 4)){
   $c=Config $name
   $status='draft'
   if(Test-Path (Join-Path (SiteDir $name) "$($c.output)/index.html")){$status='built'}
   Write-Host ('    {0,-23} {1,3} posts   {2,-13} {3}' -f $name,@(Posts $name).Count,$c.theme,$status)
  }
  if($names.Count -gt 4){Write-Host ("    + {0} more (see [1])" -f ($names.Count-4))}
  Show-Actions 'Workspace' @('[1] List sites','[2] Create site','[3] Manage site')
  Show-Actions 'Build & preview' @(
   '[4] Build one','[5] Build all','[6] Preview one','[7] Serve workspace')
  Write-Host ''
  Write-ZetaLine '    [?] Help     [0] Exit' 'Gray'
  Write-ZetaLine ('─'*60) 'DarkGray'
  $answer=Read-Host 'zeta >'
  if($answer -in @('0','q','quit','exit') -or $null -eq $answer){return}
  try{
   switch($answer){
    '1'{ListSites}
    '2'{NewSite}
    '3'{Manage-Menu (SelectItem 'Site' @(SiteNames))}
    '4'{Build (SelectItem 'Site' @(SiteNames));Dashboard}
    '5'{foreach($name in (SiteNames)){Build $name};Dashboard}
    '6'{Preview (SelectItem 'Site' @(SiteNames)) $Port}
    '7'{foreach($name in (SiteNames)){Build $name};Dashboard;Serve $Sites $Port}
    '?'{Help}
    'h'{Help}
    'help'{Help}
    default{Write-ZetaLine 'Unknown option.' 'Yellow'}
   }
  }catch{Write-ZetaLine ("[ERROR] {0}" -f $_.Exception.Message) 'Red'}
  [void](Read-Host 'Press Enter to continue')
 }
}
