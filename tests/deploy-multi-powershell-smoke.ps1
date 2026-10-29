#Requires -Version 7.0
# Offline target-selection regression, including existing single-provider deploy.conf.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$Sites=Join-Path ([IO.Path]::GetTempPath()) ('zeta-multi-'+[guid]::NewGuid().ToString('N'))
$dir=Join-Path $Sites 'demo'
$utf8=[Text.UTF8Encoding]::new($false)
function SiteDir([string]$name){if($name -ne 'demo'){throw 'Unknown site'};return $dir}
function ConfigPath([string]$name){$path=Join-Path (SiteDir $name) 'config.yaml';if(!(Test-Path $path)){throw 'Missing site'};return $path}
try{
 [void](New-Item -ItemType Directory -Force -Path (Join-Path $dir 'deploy'))
 [IO.File]::WriteAllText((Join-Path $dir 'config.yaml'),'site: demo',$utf8)
 [IO.File]::WriteAllText((Join-Path $dir 'deploy.conf'),"provider=github-pages`nrepository=example/legacy`nbranch=gh-pages`nproject=`naccount=",$utf8)
 [IO.File]::WriteAllText((Join-Path $dir 'deploy/cloudflare-pages.conf'),"provider=cloudflare-pages`nrepository=`nbranch=`nproject=demo-site`naccount=",$utf8)
 . (Join-Path $root 'lib/powershell/Deploy.ps1')
 $all=@(Get-ZetaProviders 'demo')
 if($all.Count -ne 2){throw "Expected 2 providers, got $($all.Count)"}
 $selected=@(Select-ZetaDeployTargets 'demo' 'all')
 if($selected.Count -ne 2){throw 'Explicit all selection failed'}
 $selected=@(Select-ZetaDeployTargets 'demo' 'cloudflare-pages')
 if($selected.Count -ne 1 -or $selected[0] -ne 'cloudflare-pages'){throw 'Single-provider selection failed'}
 $selected=@(Select-ZetaDeployTargets 'demo' '1,2')
 if($selected.Count -ne 2){throw 'Numbered selection failed'}
 try{$null=Select-ZetaDeployTargets 'demo' 'invalid';throw 'Invalid provider accepted'}catch{
  if($_.Exception.Message -eq 'Invalid provider accepted'){throw}
 }
 [IO.File]::WriteAllText((Join-Path $dir 'deploy/github-pages.conf'),"provider=github-pages`nrepository=example/new`nbranch=gh-pages`nproject=`naccount=",$utf8)
 $current=Read-ZetaProvider 'demo' 'github-pages'
 if($current.repository -ne 'example/new'){throw 'New config did not override legacy'}
 Write-Host '[OK] PowerShell multiple-provider selection and legacy compatibility'
}finally{
 if(Test-Path -LiteralPath $Sites){Remove-Item -LiteralPath $Sites -Recurse -Force}
}
