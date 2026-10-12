# Zeta PowerShell: help and interactive menu.
function Help{
 Write-Host @'
ZETA — Markdown-first publishing
  ./zeta.ps1                    Interactive assistant
  ./zeta.ps1 sites              List sites
  ./zeta.ps1 create             Create a site
  ./zeta.ps1 edit SITE          Edit metadata
  ./zeta.ps1 theme SITE THEME   Change theme and rebuild
  ./zeta.ps1 posts SITE         List Markdown posts
  ./zeta.ps1 new-post SITE      Add an article
  ./zeta.ps1 build SITE         Build a site
  ./zeta.ps1 build-all          Build all sites
  ./zeta.ps1 doctor SITE        Inspect deployment readiness
  ./zeta.ps1 preview SITE       Preview on localhost
  ./zeta.ps1 serve              Serve workspace
  ./zeta.ps1 clean SITE         Clean public/
  ./zeta.ps1 delete SITE        Delete local site (confirmation)
  ./zeta.ps1 fonts SITE KEY     Optional self-hosted open fonts
  ./zeta.ps1 dashboard          Generate workspace index
Requires PowerShell 7+ and Pandoc for builds. No Bash/WSL/Node.
'@
}
function Menu{
 while($true){
  Clear-Host
  Write-Host '  ZETA / create · write · publish' -ForegroundColor Cyan
  Write-Host ('-'*56)
  Write-Host ("  Workspace   $((SiteNames).Count) sites")
  if(Get-Command pandoc -ErrorAction SilentlyContinue){Write-Host '  Renderer    ready' -ForegroundColor Green}
  else{Write-Host '  Renderer    Pandoc missing' -ForegroundColor Yellow}
  Write-Host ('-'*56)
  ListSites
  Write-Host '[1] List sites       [2] Create      [3] New post'
  Write-Host '[4] Build one        [5] Build all   [6] Preview'
  Write-Host '[7] Theme            [8] Doctor      [9] Fonts   [?] Help   [0] Exit'
  $a=Read-Host 'zeta >'
  try{
   switch($a){
    '1'{ListSites}
    '2'{NewSite}
    '3'{NewPost (SelectItem 'Site' (SiteNames))}
    '4'{Build (SelectItem 'Site' (SiteNames));Dashboard}
    '5'{foreach($n in (SiteNames)){Build $n};Dashboard}
    '6'{Preview (SelectItem 'Site' (SiteNames)) $Port}
    '7'{ThemeSite (SelectItem 'Site' (SiteNames)) ''}
    '8'{Doctor (SelectItem 'Site' (SiteNames))}
    '9'{FontSite (SelectItem 'Site' (SiteNames)) ''}
    '?'{Help}
    '0'{return}
    default{Write-Host 'Invalid selection' -ForegroundColor Yellow}
   }
  }catch{Write-Host "[ERROR] $_" -ForegroundColor Red}
  [void](Read-Host 'Enter to continue')
 }
}
