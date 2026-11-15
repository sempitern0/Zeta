#Requires -Version 7.0
# Regression of the PowerShell generated-output guard. Requires no Pandoc.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
. (Join-Path $Root 'lib/powershell/BuildGuard.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('zeta-output-guard-'+[guid]::NewGuid().ToString('N'))
try{
  $public=Join-Path $temp 'public'
  [void](New-Item -ItemType Directory -Path (Join-Path $public 'styles') -Force)
  $style=Join-Path $public 'styles/theme.css'
  $index=Join-Path $public 'index.html'
  $manifest=Join-Path $temp '.zeta-build-manifest.tsv'
  [IO.File]::WriteAllText($style,'original')
  [IO.File]::WriteAllText($index,'<p>original</p>')
  [IO.File]::WriteAllLines($manifest,[string[]]@(Get-ZetaBuildManifest $public))
  Assert-ZetaBuildOutputSafe $public $manifest 'test' $false
  [IO.File]::WriteAllText($style,'edited')
  $blocked=$false
  try{Assert-ZetaBuildOutputSafe $public $manifest 'test' $false}catch{$blocked=$true}
  if(-not $blocked){throw 'Modified generated CSS was not protected'}
  Assert-ZetaBuildOutputSafe $public $manifest 'test' $true
  [IO.File]::WriteAllText($style,'original')
  [IO.File]::WriteAllText((Join-Path $public 'custom.txt'),'extra')
  $blocked=$false
  try{Assert-ZetaBuildOutputSafe $public $manifest 'test' $false}catch{$blocked=$true}
  if(-not $blocked){throw 'Untracked output was not protected'}
  Remove-Item (Join-Path $public 'custom.txt')
  Remove-Item $index
  $blocked=$false
  try{Assert-ZetaBuildOutputSafe $public $manifest 'test' $false}catch{$blocked=$true}
  if(-not $blocked){throw 'Deleted output was not detected'}
  [IO.File]::WriteAllText($index,'<p>original</p>')
  Remove-Item $manifest
  $blocked=$false
  try{Assert-ZetaBuildOutputSafe $public $manifest 'test' $false}catch{$blocked=$true}
  if(-not $blocked){throw 'Legacy output without baseline was not protected'}
  Write-Host '[OK] PowerShell output guard: clean, modified, untracked, deleted, legacy, force.'
}finally{
  if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
