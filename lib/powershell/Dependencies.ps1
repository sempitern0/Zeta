# Zeta Windows dependency helper. Pandoc is the only required build-time application.
function Test-ZetaPandoc {
 return [bool](Get-Command pandoc -ErrorAction SilentlyContinue)
}
function Install-ZetaPandoc {
 param([switch]$AssumeYes)
 if(Test-ZetaPandoc){
  Write-Host '[OK] Pandoc already available.' -ForegroundColor Green
  return $true
 }
 if(-not $IsWindows){
  Write-Warning 'The guided installer is Windows-only. See https://pandoc.org/installing.html'
  return $false
 }
 if(-not (Get-Command winget -ErrorAction SilentlyContinue)){
  Write-Warning 'winget is not available. Install Pandoc from https://pandoc.org/installing.html then reopen PowerShell.'
  return $false
 }
 if(-not $AssumeYes){
  Write-Host 'Install the official JohnMacFarlane.Pandoc package using Windows Package Manager?'
  $reply=Read-Host 'Install now? [y/N]'
  if($reply -notin @('y','Y','yes','YES','s','S','si','sí')){
   Write-Host 'Installation skipped; the site source files can still be created.'
   return $false
  }
 }
 Write-Host '[ZETA] Installing Pandoc with winget...' -ForegroundColor Cyan
 & winget install --source winget --exact --id JohnMacFarlane.Pandoc --accept-package-agreements --accept-source-agreements
 if($LASTEXITCODE -ne 0){
  throw "winget installation failed (exit code $LASTEXITCODE). Use https://pandoc.org/installing.html"
 }
 $machine=[Environment]::GetEnvironmentVariable('Path','Machine')
 $user=[Environment]::GetEnvironmentVariable('Path','User')
 $env:Path=(@($env:Path,$machine,$user) | Where-Object {$_}) -join ';'
 if(Test-ZetaPandoc){
  Write-Host '[OK] Pandoc installed and detected.' -ForegroundColor Green
  return $true
 }
 Write-Warning 'Installer finished, but Pandoc is not on this session PATH. Restart PowerShell and run pandoc --version.'
 return $false
}
function Assert-ZetaPandoc {
 if(-not (Test-ZetaPandoc)){
  throw 'Pandoc is required for builds. On Windows run .\zeta.ps1 install-pandoc (or see https://pandoc.org/installing.html). Site creation works without Pandoc.'
 }
}
function Show-ZetaDependencies {
 if(Test-ZetaPandoc){
  Write-Host '[OK] Pandoc available' -ForegroundColor Green
  & pandoc --version | Select-Object -First 1 | Out-Host
 }else{
  Write-Host '[MISSING] Pandoc (needed only to build HTML)' -ForegroundColor Yellow
  if($IsWindows){
   Write-Host 'Try: .\zeta.ps1 install-pandoc'
  }else{
   Write-Host 'See: https://pandoc.org/installing.html'
  }
 }
 if($IsWindows){
  if(Get-Command winget -ErrorAction SilentlyContinue){
   Write-Host '[OK] winget available (optional installer)' -ForegroundColor Green
  }else{
   Write-Host '[INFO] winget unavailable; manual Pandoc setup supported'
  }
 }
}
